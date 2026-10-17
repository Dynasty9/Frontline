"""Read the MJPEG AVIs that Godot's movie writer makes (and that build.py writes).

    avi.py info TAKE.avi
    avi.py sheet TAKE.avi OUT.jpg [--every 2] [--from 0] [--to END] [--cols 5]
    avi.py frame TAKE.avi SECONDS OUT.jpg

A sheet is how you choose cuts: a grid of frames, each stamped with its time.
Start with --every 2 over a whole take, then go back over the stretch you want
with --from/--to and --every 0.5 to find the exact seconds.

Godot tags its video chunks 00db and its audio 01wb (one 48 kHz stereo 16-bit
block per frame), and the recordings run at 30 fps. Needs Pillow.
"""

from __future__ import annotations

import argparse
import io
import mmap
import struct
import sys
from pathlib import Path

FPS = 30


class Avi:
    """A RIFF AVI's video and audio chunks, read straight from a memory map."""

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self._f = open(self.path, "rb")
        self.data = mmap.mmap(self._f.fileno(), 0, access=mmap.ACCESS_READ)
        self.video: list[tuple[int, int]] = []
        self.audio: list[tuple[int, int]] = []
        self._walk(0, len(self.data))

    def _walk(self, off: int, end: int) -> None:
        d = self.data
        while off + 8 <= end:
            cid = d[off : off + 4]
            size = struct.unpack("<I", d[off + 4 : off + 8])[0]
            body = off + 8
            if cid in (b"RIFF", b"LIST"):
                # a list's size can be stale in an unfinished file: never past the end
                self._walk(body + 4, min(body + size, end))
            elif cid in (b"00dc", b"00db"):
                self.video.append((body, size))
            elif cid == b"01wb":
                self.audio.append((body, size))
            off = body + size + (size & 1)

    def __len__(self) -> int:
        return len(self.video)

    def seconds(self) -> float:
        return len(self.video) / FPS

    def jpeg(self, i: int) -> bytes:
        o, n = self.video[max(0, min(i, len(self.video) - 1))]
        return self.data[o : o + n]

    def image(self, i: int):
        from PIL import Image

        return Image.open(io.BytesIO(self.jpeg(i))).convert("RGB")

    def pcm(self, i: int) -> bytes:
        """The sound that went with frame i (empty if there's none)."""
        if i < 0 or i >= len(self.audio):
            return b""
        o, n = self.audio[i]
        return self.data[o : o + n]


def sheet(avi: Avi, out: str, every: float = 2.0, start: float = 0.0, end: float | None = None, cols: int = 5) -> int:
    from PIL import Image, ImageDraw

    end = avi.seconds() if end is None else min(end, avi.seconds())
    idx = []
    t = start
    while t < end - 1e-6:
        idx.append(int(round(t * FPS)))
        t += every
    tw, th = 400, 225
    rows = max(1, (len(idx) + cols - 1) // cols)
    img = Image.new("RGB", (tw * cols, th * rows))
    draw = ImageDraw.Draw(img)
    for k, i in enumerate(idx):
        x, y = (k % cols) * tw, (k // cols) * th
        img.paste(avi.image(i).resize((tw, th)), (x, y))
        draw.rectangle((x, y, x + 74, y + 14), fill=(0, 0, 0))
        draw.text((x + 4, y + 2), f"{i / FPS:6.1f}s", fill=(255, 220, 0))
    img.save(out, quality=85)
    return len(idx)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("info")
    p.add_argument("avi")
    p = sub.add_parser("sheet")
    p.add_argument("avi")
    p.add_argument("out")
    p.add_argument("--every", type=float, default=2.0)
    p.add_argument("--from", dest="start", type=float, default=0.0)
    p.add_argument("--to", dest="end", type=float)
    p.add_argument("--cols", type=int, default=5)
    p = sub.add_parser("frame")
    p.add_argument("avi")
    p.add_argument("seconds", type=float)
    p.add_argument("out")
    a = ap.parse_args()

    avi = Avi(a.avi)
    if a.cmd == "info":
        w, h = avi.image(0).size if len(avi) else (0, 0)
        print(f"{a.avi}: {len(avi)} frames, {avi.seconds():.1f} s, {w}x{h}, audio blocks: {len(avi.audio)}")
    elif a.cmd == "sheet":
        n = sheet(avi, a.out, a.every, a.start, a.end, a.cols)
        print(f"{a.out}: {n} frames")
    elif a.cmd == "frame":
        avi.image(int(round(a.seconds * FPS))).save(a.out, quality=92)
        print(a.out)


if __name__ == "__main__":
    sys.exit(main())
