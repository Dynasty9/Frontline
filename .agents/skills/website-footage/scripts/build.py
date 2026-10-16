"""Cut the recorded takes into the website's clips and stills (shots.json).

    build.py NAME [NAME ...]              build those outputs and/or stills (an output's
                                          poster still shares its name, e.g. reel)
    build.py --all                        every output and every still
    build.py --stills                     every still
      [--install] [--work DIR] [--encoder auto|ffmpeg|mf]

For each output: the cuts are taken from WORK/takes/TAKE.avi, scaled to the
output's size, graded, and joined with crossfades; loop_fade blends the end
into the start so a looping clip has no jump. With "audio": true the sound
comes too, each cut brought to about the same loudness and the whole run
through a peak limiter; cuts with a "caption" give a WebVTT captions file.
The result is encoded as H.264 MP4 (moov first, so it starts playing while it
downloads), with its first frame as a JPEG poster, into WORK/build/. A
contact sheet of what was built goes beside it (NAME.preview.jpg): look at it.

--install copies what was built into web/public/media and checks the sizes
against each output's max_kb.

Encoding uses ffmpeg if it's on the PATH, else (Windows) Media Foundation
through encode_mf.ps1. Needs Pillow and numpy.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance

HERE = Path(__file__).resolve().parent
SKILL = HERE.parent
REPO = SKILL.parents[2]
MEDIA = REPO / "web" / "public" / "media"
sys.path.insert(0, str(HERE))
from avi import FPS, Avi, sheet  # noqa: E402

RATE = 48000
SPF = RATE // FPS  # audio sample frames per video frame


class Takes:
    def __init__(self, folder: Path):
        self.folder = folder
        self.open: dict[str, Avi] = {}

    def __getitem__(self, name: str) -> Avi:
        if name not in self.open:
            p = self.folder / f"{name}.avi"
            if not p.exists():
                sys.exit(f"No recording of take '{name}' at {p}: record it first (record.py {name}).")
            self.open[name] = Avi(p)
        return self.open[name]


def grade(im: Image.Image, g: dict) -> Image.Image:
    for key, fn in (("brightness", ImageEnhance.Brightness), ("contrast", ImageEnhance.Contrast),
                    ("saturation", ImageEnhance.Color), ("sharpness", ImageEnhance.Sharpness)):
        if g.get(key, 1.0) != 1.0:
            im = fn(im).enhance(g[key])
    return im


def frame(takes: Takes, take: str, i: int, size: tuple[int, int], g: dict) -> Image.Image:
    im = takes[take].image(i)
    if im.size != size:
        im = im.resize(size, Image.LANCZOS)
    return grade(im, g)


def sound(takes: Takes, take: str, i: int) -> np.ndarray:
    out = np.zeros((SPF, 2), dtype=np.float32)
    raw = takes[take].pcm(i)
    if raw:
        a = np.frombuffer(raw, dtype="<i2").astype(np.float32).reshape(-1, 2) / 32768.0
        out[: min(SPF, len(a))] = a[:SPF]
    return out


def plan(spec: dict, takes: Takes) -> tuple[list[list[tuple[float, tuple]]], list[float]]:
    """Each output frame as a weighted blend of source frames (take, index, cut gain), and each cut's start time."""
    fade = int(spec.get("fade", 8))
    audio = spec.get("audio", False)
    out: list[list[tuple[float, tuple]]] = []
    starts: list[float] = []
    for c in spec["cuts"]:
        a, b = int(round(c["from"] * FPS)), int(round(c["to"] * FPS))
        n = len(takes[c["take"]])
        if b > n:
            sys.exit(f"Cut {c} runs past the end of take '{c['take']}' ({n / FPS:.1f} s).")
        gain = level(takes, c["take"], a, b, spec) if audio else 1.0
        frames = [(c["take"], i, gain) for i in range(a, b)]
        k = min(fade, len(out), len(frames)) if out else 0
        starts.append((len(out) - k) / FPS)
        for j in range(k):  # the last k frames so far blend into this cut's first k
            t = (j + 1) / (k + 1)
            e = out[len(out) - k + j]
            out[len(out) - k + j] = [(w * (1 - t), f) for w, f in e] + [(t, frames[j])]
        out.extend([[(1.0, f)] for f in frames[k:]])
    lf = int(spec.get("loop_fade", 0))
    if lf:
        # the tail fades into the head and the head is dropped: it loops without a jump
        head, out = out[:lf], out[lf:]
        starts = [max(0.0, s - lf / FPS) for s in starts]
        for j in range(lf):
            t = (j + 1) / (lf + 1)
            e = out[len(out) - lf + j]
            out[len(out) - lf + j] = [(w * (1 - t), f) for w, f in e] + [(w * t, f) for w, f in head[j]]
    return out, starts


def level(takes: Takes, take: str, a: int, b: int, spec: dict) -> float:
    """A gain that brings this cut's sound to about the same loudness (RMS) as the others, boosting 12 dB at most."""
    x = np.concatenate([sound(takes, take, i) for i in range(a, b)])
    rms = float(np.sqrt((x * x).mean())) + 1e-9
    return min(4.0, max(0.5, spec.get("audio_rms", 0.11) / rms))


def limit(pcm: np.ndarray) -> np.ndarray:
    """A peak limiter (instant attack, 150 ms release, in 10 ms blocks), then peaks at about -2.4 dB."""
    blk = RATE // 100
    nb = (len(pcm) + blk - 1) // blk
    pad = np.zeros((nb * blk, 2), dtype=np.float32)
    pad[: len(pcm)] = pcm
    peaks = np.abs(pad).reshape(nb, blk, 2).max(axis=(1, 2))
    env = np.empty(nb, dtype=np.float32)
    e, rel = 0.0, np.exp(-1.0 / 15.0)
    for k in range(nb):
        e = max(float(peaks[k]), e * rel)
        env[k] = e
    gain = np.minimum(1.0, 0.45 / np.maximum(env, 1e-9))
    g = np.interp(np.arange(nb * blk) / blk, np.arange(nb), gain)[: len(pcm)].astype(np.float32)
    pcm = pcm * g[:, None]
    pcm *= 0.76 / max(1e-9, float(np.abs(pcm).max()))
    return np.tanh(pcm * 1.05) / np.tanh(1.05)


def write_avi(path: Path, jpegs: list[bytes], pcm: bytes | None, size: tuple[int, int]) -> None:
    """An AVI 1.0 of MJPEG frames (and PCM, one block per frame) for the encoder to read."""
    w, h = size
    nf = len(jpegs)
    mx = max(len(j) for j in jpegs)
    blocks = [pcm[k * SPF * 4 : (k + 1) * SPF * 4] for k in range(nf)] if pcm is not None else []

    def ck(fcc: bytes, body: bytes) -> bytes:
        return fcc + struct.pack("<I", len(body)) + body + (b"\0" if len(body) & 1 else b"")

    def lst(typ: bytes, body: bytes) -> bytes:
        return b"LIST" + struct.pack("<I", len(body) + 4) + typ + body

    avih = struct.pack("<IIIIIIIIII4I", 1000000 // FPS, mx * FPS, 0, 0x10, nf, 0, 2 if blocks else 1, mx, w, h, 0, 0, 0, 0)
    strh = struct.pack("<4s4sIHHIIIIIIIIhhhh", b"vids", b"MJPG", 0, 0, 0, 0, 1, FPS, 0, nf, mx, 0xFFFFFFFF, 0, 0, 0, w, h)
    strf = struct.pack("<IiiHH4sIiiII", 40, w, h, 1, 24, b"MJPG", w * h * 3, 0, 0, 0, 0)
    strl = lst(b"strl", ck(b"strh", strh) + ck(b"strf", strf))
    if blocks:
        astrh = struct.pack("<4s4sIHHIIIIIIIIhhhh", b"auds", bytes(4), 0, 0, 0, 0, 4, RATE * 4, 0, nf * SPF, SPF * 4,
                            0xFFFFFFFF, 4, 0, 0, 0, 0)
        astrf = struct.pack("<HHIIHHH", 1, 2, RATE, RATE * 4, 4, 16, 0)
        strl += lst(b"strl", ck(b"strh", astrh) + ck(b"strf", astrf))
    movi = bytearray()
    idx = bytearray()
    for k, j in enumerate(jpegs):
        idx += struct.pack("<4sIII", b"00dc", 0x10, 4 + len(movi), len(j))
        movi += ck(b"00dc", j)
        if blocks:
            idx += struct.pack("<4sIII", b"01wb", 0x10, 4 + len(movi), len(blocks[k]))
            movi += ck(b"01wb", blocks[k])
    body = b"AVI " + lst(b"hdrl", ck(b"avih", avih) + strl) + lst(b"movi", bytes(movi)) + ck(b"idx1", bytes(idx))
    path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)


def encode(avi: Path, mp4: Path, spec: dict, how: str) -> None:
    w, h = spec["size"]
    kbps = int(spec["kbps"])
    akbps = int(spec.get("audio_kbps", 128)) if spec.get("audio") else 0
    if how == "auto":
        how = "ffmpeg" if shutil.which("ffmpeg") else "mf" if os.name == "nt" else ""
    if how == "ffmpeg":
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(avi), "-c:v", "libx264", "-profile:v", "high",
               "-pix_fmt", "yuv420p", "-preset", "slow", "-b:v", f"{kbps}k", "-maxrate", f"{kbps * 3 // 2}k",
               "-bufsize", f"{kbps * 2}k", "-movflags", "+faststart"]
        cmd += ["-c:a", "aac", "-b:a", f"{akbps}k"] if akbps else ["-an"]
        subprocess.run(cmd + [str(mp4)], check=True)
        return
    if how != "mf":
        sys.exit("No encoder: install ffmpeg (or run on Windows, which has Media Foundation).")
    raw = mp4.with_suffix(".raw.mp4")
    ps = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(HERE / "encode_mf.ps1"),
          str(avi), str(raw.parent), raw.name, str(w), str(h), str(kbps), str(FPS), str(akbps)]
    r = subprocess.run(ps, capture_output=True, text=True)
    if r.returncode != 0 or not raw.exists():
        sys.exit(f"Media Foundation couldn't encode {avi}:\n{r.stdout}{r.stderr}")
    faststart(raw, mp4)
    raw.unlink()


def faststart(src: Path, dst: Path) -> None:
    """Move the moov box in front of mdat (Media Foundation writes it last) and drop vendor uuid boxes."""
    d = src.read_bytes()

    def boxes(buf: bytes | bytearray, o: int, end: int):
        while o < end:
            sz, t = struct.unpack(">I4s", buf[o : o + 8])
            hdr = 8
            if sz == 1:
                sz, hdr = struct.unpack(">Q", buf[o + 8 : o + 16])[0], 16
            elif sz == 0:
                sz = end - o
            yield o, sz, t, hdr
            o += sz

    top = {t: (o, sz) for o, sz, t, _ in boxes(d, 0, len(d))}
    fo, fs = top[b"ftyp"]
    mo, ms = top[b"moov"]
    do, ds = top[b"mdat"]
    if mo < do:
        dst.write_bytes(d)
        return
    moov = bytearray(d[mo : mo + ms])
    delta = fs + ms - do
    containers = {b"moov", b"trak", b"mdia", b"minf", b"stbl", b"edts", b"dinf"}

    def patch(o: int, end: int) -> None:
        for bo, sz, t, hdr in boxes(moov, o, end):
            if t in containers:
                patch(bo + hdr, bo + sz)
            elif t in (b"stco", b"co64"):
                n = struct.unpack(">I", moov[bo + 12 : bo + 16])[0]
                fmt, w = (">I", 4) if t == b"stco" else (">Q", 8)
                for i in range(n):
                    p = bo + 16 + w * i
                    struct.pack_into(fmt, moov, p, struct.unpack(fmt, moov[p : p + w])[0] + delta)

    patch(8, len(moov))
    dst.write_bytes(d[fo : fo + fs] + bytes(moov) + d[do : do + ds])


def vtt(spec: dict, starts: list[float], total: float) -> str | None:
    cues = [(s, c["caption"]) for s, c in zip(starts, spec["cuts"]) if c.get("caption")]
    if not cues:
        return None

    def ts(t: float) -> str:
        return f"{int(t // 60):02d}:{t % 60:06.3f}"

    ends = [s for s, _ in cues[1:]] + [total]
    return "WEBVTT\n\n" + "\n".join(f"{ts(s)} --> {ts(max(s, e - 0.02))}\n{text}\n" for (s, text), e in zip(cues, ends))


def build_output(name: str, spec: dict, takes: Takes, out: Path, how: str) -> None:
    size = tuple(spec["size"])
    g = spec.get("grade", {})
    frames, starts = plan(spec, takes)
    n = len(frames)
    fi, fo = int(spec.get("fade_in", 0)), int(spec.get("fade_out", 0))
    black = Image.new("RGB", size)
    jpegs: list[bytes] = []
    pcm: list[np.ndarray] = []
    print(f"{name}: {n} frames ({n / FPS:.1f} s) from {len(spec['cuts'])} cuts ...", flush=True)
    for k, entry in enumerate(frames):
        im, acc = None, 0.0
        for w, (take, i, _gain) in entry:
            if w <= 0.001:
                continue
            x = frame(takes, take, i, size, g)
            acc += w
            im = x if im is None else Image.blend(im, x, w / acc)
        dim = 1.0
        if fi and k < fi:
            dim = (k + 1) / (fi + 1)
        if fo and k >= n - fo:
            dim = (n - k) / (fo + 1)
        if dim < 1.0:
            im = Image.blend(black, im, dim)
        if k == 0:
            im.save(out / f"{name}.jpg", quality=82, optimize=True, progressive=True)
        b = io.BytesIO()
        im.save(b, "JPEG", quality=95)
        jpegs.append(b.getvalue())
        if spec.get("audio"):
            a = np.zeros((SPF, 2), dtype=np.float32)
            for w, (take, i, gain) in entry:
                if w > 0.001:
                    a += w * gain * sound(takes, take, i)
            pcm.append(a * dim)
    pcm16 = None
    if spec.get("audio"):
        pcm16 = (np.clip(limit(np.concatenate(pcm)), -1, 1) * 32767).astype("<i2").tobytes()
    avi = out / f"{name}.cut.avi"
    write_avi(avi, jpegs, pcm16, size)
    sheet(Avi(avi), str(out / f"{name}.preview.jpg"), every=max(0.5, n / FPS / 20), cols=5)
    encode(avi, out / f"{name}.mp4", spec, how)
    avi.unlink()
    captions = vtt(spec, starts, n / FPS)
    if captions:
        (out / f"{name}.vtt").write_text(captions, encoding="utf-8", newline="\n")
    print(f"{name}: {(out / f'{name}.mp4').stat().st_size / 1e6:.2f} MB, preview {out / f'{name}.preview.jpg'}", flush=True)


def build_still(name: str, spec: dict, takes: Takes, out: Path) -> None:
    im = takes[spec["take"]].image(int(round(spec["at"] * FPS))).resize((1280, 720), Image.LANCZOS)
    im = grade(im, {"brightness": spec.get("brightness", 1.0), "contrast": 1.1, "saturation": 1.14})
    im.save(out / f"{name}.jpg", quality=80, optimize=True, progressive=True)
    print(f"{name}.jpg: {(out / f'{name}.jpg').stat().st_size // 1000} KB")


def install(names: list[str], stills: list[str], shots: dict, out: Path) -> None:
    MEDIA.mkdir(parents=True, exist_ok=True)
    for n in names:
        for ext in ("mp4", "jpg", "vtt"):
            if (out / f"{n}.{ext}").exists():
                shutil.copy2(out / f"{n}.{ext}", MEDIA / f"{n}.{ext}")
    for s in stills:  # after the outputs: a still can stand in for an output's first-frame poster
        shutil.copy2(out / f"{s}.jpg", MEDIA / f"{s}.jpg")
    print(f"\ninstalled in {MEDIA}:")
    total = 0
    for n, spec in shots["outputs"].items():
        p = MEDIA / f"{n}.mp4"
        if not p.exists():
            print(f"  {n}.mp4 MISSING")
            continue
        kb = p.stat().st_size // 1000
        total += p.stat().st_size
        over = f"  OVER its budget of {spec['max_kb']} KB" if kb > spec.get("max_kb", 1e9) else ""
        print(f"  {n}.mp4 {kb} KB{over}")
    total += sum(p.stat().st_size for p in MEDIA.iterdir() if p.suffix != ".mp4")
    print(f"  all media: {total / 1e6:.1f} MB")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("outputs", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--stills", action="store_true", help="build the stills (with --all, or alone)")
    ap.add_argument("--install", action="store_true")
    ap.add_argument("--work")
    ap.add_argument("--encoder", default="auto", choices=["auto", "ffmpeg", "mf"])
    a = ap.parse_args()

    shots = json.loads((SKILL / "shots.json").read_text(encoding="utf-8"))
    work = Path(a.work or os.environ.get("FRONTLINE_FOOTAGE_DIR") or Path(tempfile.gettempdir()) / "frontline-footage")
    out = work / "build"
    out.mkdir(parents=True, exist_ok=True)
    takes = Takes(work / "takes")

    outputs, all_stills = shots["outputs"], shots.get("stills", {})
    unknown = [n for n in a.outputs if n not in outputs and n not in all_stills]
    if unknown:
        sys.exit(f"Unknown: {unknown} (outputs: {list(outputs)}; stills: {list(all_stills)})")
    names = list(outputs) if a.all else [n for n in a.outputs if n in outputs]
    # a name can be a still (m-beachhead), and an output's poster still shares its name (reel)
    stills = list(all_stills) if (a.all or a.stills) else [n for n in a.outputs if n in all_stills]
    if not names and not stills:
        sys.exit("Name some outputs, or --all / --stills.")

    for n in names:
        build_output(n, shots["outputs"][n], takes, out, a.encoder)
    for s in stills:
        build_still(s, shots["stills"][s], takes, out)
    if a.install:
        install(names, stills, shots, out)


if __name__ == "__main__":
    main()
