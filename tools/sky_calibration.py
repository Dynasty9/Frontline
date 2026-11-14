"""How bright Frontline's three skies are, measured offline.

The game draws one of three skies. The physical sky (PhysicalSky.SHADER in
scripts/game/physical_sky.gd) marches each view ray through Rayleigh, Mie and
ozone air under a thin cloud layer; the painted sky (SKY_SHADER in
scripts/game/atmosphere.gd) is a gradient with a sun glow, clouds and stars;
midday's photographed sky (PHOTO_SKY_SHADER) is an HDR panorama turned so its
sun sits where the game's sun is. The sky is the background, and through its
radiance cubemap it is also the battlefield's ambient light and reflections,
so its average brightness decides the exposure and the light in the shade.
Letting time pass moves the sun, and the sky's brightness has to stay steady
while it does; that needs numbers for how bright each sky is for a given sun.

This tool ports the three sky() functions to numpy line for line, vectorised
over view directions, and evaluates them over a Fibonacci sphere (each
direction an equal share of solid angle) plus a fine polar patch round the sun,
whose disc and glow are narrower than the Fibonacci spacing. It reports
solid-angle-weighted means of linear RGB and Rec.709 luminance over the upper
hemisphere and over the whole sphere (and, as a further reading, the
cosine-weighted hemisphere: the light falling on level ground).

Step 1 checks the port against the game's own calibration. PhysicalSky.MOODS
gives each clear mood a sky_energy chosen so the physical sky matches "the
painted sky's average over the dome"; the tool recomputes painted /
physical(sky_energy 1) under each way of averaging (hemisphere or sphere,
radiance-cubemap pass or visible background, luminance or one channel) and
shows which reproduces those numbers. The physical sky is affine in
sky_energy, not proportional (the sun's disc and the sunlit cloud tops do not
scale with it), so it also shows the sky_energy that would match exactly.

Step 2 prints, with the averaging that matched best: the physical sky's mean
against sun elevation, the painted sky's mean per mood, the photo sky's mean
next to the physical sky under midday's sun, and the physical dusk sky
continued below the horizon (zenith, horizon and dome colours) to compare with
the painted night.

Run from the repository root, numpy only; the physical sky's ~170 suns are marched on
a pool of processes, so it takes a minute or so:
    python -I tools/sky_calibration.py

Where the port is not bit-exact: the march runs in float64 (the GPU in float32; it
moves means by far less than the figures shown), and the cloud and star hashes run in
float32 like the GPU's but may round differently where the GPU fuses operations, so
the cloud pattern can differ in detail while its coverage, which is what the means
see, does not. The photo is integrated texel by texel at the full resolution the game
samples (it has no mipmaps), with its 16 clamp per texel.
"""

import hashlib
import math
import os
import re
import time

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHYS_GD = os.path.join(ROOT, "scripts", "game", "physical_sky.gd")
ATMO_GD = os.path.join(ROOT, "scripts", "game", "atmosphere.gd")
HDR = os.path.join(ROOT, "assets", "sky", "kloofendal_partly_cloudy_2k.hdr")

N_PHYS = 1 << 14  # the physical sky marches 16 x 6 steps per direction (within 0.1% of 2^18)
N_PAINT = 1 << 18  # the night's tiny stars included, means move < 0.1% from here to 2^21
REC709 = np.array([0.2126, 0.7152, 0.0722])
TAU = 2.0 * math.pi

# sha1 of each shader's source as ported here: if one changes, so must the port. The
# painted sky is the whole SKY_SHADER or (since Time passes) its PAINTED_SKY function,
# the photo's lookup the whole PHOTO_SKY_SHADER or PHOTO_SKY_FN; both forms are known.
PORTED = {
    "PhysicalSky.SHADER": {"c402dfa9229ede39c48394bf7ad23def969202bf"},
    "Atmosphere.PAINTED_SKY": {"f9ee781d934de5ec669b0627d66493f08bb1af66", "37601a65243098821b48502242db0a9acba35528"},
    "Atmosphere.PHOTO_SKY": {"34f1b7378e66542d79e893947c9dc2bcad106692", "a5b4af108212c30a2283c2bb7638414fde1836ef"},
}


# --- the game's sources --------------------------------------------------------------

def _read(path):
    with open(path, encoding="utf-8") as f:
        return f.read().replace("\r\n", "\n")


def _shader(src, *names):
    for name in names:
        m = re.search(r'\nconst %s := """\n(.*?)"""' % name, src, re.S)
        if m:
            return m.group(1)
    return ""


def _moods_block(src):
    return re.search(r"\nconst MOODS := \{\n(.*?)\n\}", src, re.S).group(1)


def _atmo_moods(src):
    out = {}
    for name, body in re.findall(r'"(\w+)":\s*\{(.*?)\}', _moods_block(src), re.S):
        d = {}
        for key, val in re.findall(r'"(\w+)":\s*(Color\([^)]*\)|-?[\d.]+)', body):
            d[key] = tuple(float(x) for x in val[6:-1].split(",")) if val.startswith("Color") else float(val)
        out[name] = d
    return out


def _phys_moods(src):
    return {n: [float(x) for x in v.split(",")] for n, v in re.findall(r'"(\w+)":\s*\[([^\]]*)\]', _moods_block(src))}


PHYS_SRC = _read(PHYS_GD)
ATMO_SRC = _read(ATMO_GD)
MOODS = _atmo_moods(ATMO_SRC)  # Atmosphere.MOODS
PHYS_MOODS = _phys_moods(PHYS_SRC)  # PhysicalSky.MOODS: [turbidity, sky_energy, cloudiness]


def check_ports():
    srcs = {
        "PhysicalSky.SHADER": _shader(PHYS_SRC, "SHADER"),
        "Atmosphere.PAINTED_SKY": _shader(ATMO_SRC, "PAINTED_SKY", "SKY_SHADER"),
        "Atmosphere.PHOTO_SKY": _shader(ATMO_SRC, "PHOTO_SKY_FN", "PHOTO_SKY_SHADER"),
    }
    for name, code in srcs.items():
        h = hashlib.sha1(code.encode()).hexdigest()
        if h not in PORTED[name]:
            print("WARNING: %s has changed since this port was written (sha1 %s): check the port" % (name, h))


# --- colour and GLSL helpers ---------------------------------------------------------

def srgb_to_linear(c):
    """Godot's Color.srgb_to_linear(), which a source_color uniform goes through."""
    c = np.asarray(c, dtype=np.float64)
    return np.where(c < 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c < 0.0031308, 12.92 * c, 1.055 * np.power(np.maximum(c, 0.0), 1.0 / 2.4) - 0.055)


def lum(rgb):
    return np.asarray(rgb) @ REC709


def smoothstep(e0, e1, x):
    # GLSL's formula, which GPUs also follow with the edges reversed
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    return a * (1.0 - t) + b * t


F32 = np.float32


def fract(x):
    return x - np.floor(x)


def hash2(px, py):
    """hash(vec2) of both sky shaders, in float32 as the GPU runs it."""
    k = F32(0.1031)
    c = F32(33.33)
    qx = fract(px * k)
    qy = fract(py * k)
    qz = qx  # vec3(p.xyx)
    dd = qx * (qy + c) + qy * (qz + c) + qz * (qx + c)  # dot(q, q.yzx + 33.33)
    qx = qx + dd
    qy = qy + dd
    qz = qz + dd
    return fract((qx + qy) * qz)


def noise(px, py):
    ix = np.floor(px)
    iy = np.floor(py)
    fx = px - ix
    fy = py - iy
    fx = fx * fx * (F32(3.0) - F32(2.0) * fx)
    fy = fy * fy * (F32(3.0) - F32(2.0) * fy)
    one = F32(1.0)
    return mix(mix(hash2(ix, iy), hash2(ix + one, iy), fx), mix(hash2(ix, iy + one), hash2(ix + one, iy + one), fx), fy)


def fbm(px, py):
    px = px.astype(F32)
    py = py.astype(F32)
    v = np.zeros_like(px)
    a = F32(0.5)
    for _ in range(5):
        v += a * noise(px, py)
        px = px * F32(2.07)
        py = py * F32(2.07)
        a = a * F32(0.5)
    return v


def cloud_fbm(d):
    """fbm(uv * 1.6) with uv = d.xz / (d.y + 0.18) * 1.2: the cloud field both skies share."""
    out = np.zeros(len(d))
    up = d[:, 1] > 0.0
    df = d[up].astype(F32)
    k = F32(1.2) / (df[:, 1] + F32(0.18))
    out[up] = fbm(df[:, 0] * k * F32(1.6), df[:, 2] * k * F32(1.6))
    return out


# --- directions ----------------------------------------------------------------------

def sun_dir(elev, azim):
    """A DirectionalLight3D with rotation_degrees (-elev, azim, 0) faces away from its
    basis.z; Basis.from_euler's default order is YXZ (Ry * Rx * Rz)."""
    x, y = math.radians(-elev), math.radians(azim)
    rx = np.array([[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]])
    ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    return (ry @ rx)[:, 2]


def fibonacci(n):
    i = np.arange(n, dtype=np.float64) + 0.5
    y = 1.0 - 2.0 * i / n
    r = np.sqrt(np.maximum(0.0, 1.0 - y * y))
    phi = i * (math.pi * (3.0 - math.sqrt(5.0)))
    return np.stack([r * np.cos(phi), y, r * np.sin(phi)], axis=-1)


class Dirs:
    """View directions with the solid angle each stands for, and the cloud field there."""

    def __init__(self, d, w, fb=None):
        self.d = d
        self.w = w
        self.fbm = cloud_fbm(d) if fb is None else fb

    def means(self, col):
        return weighted_means(col, self.w, self.d[:, 1])


def weighted_means(col, w, y):
    """Solid-angle-weighted means of col (M, 3) over the upper hemisphere and the whole
    sphere, and the cosine-weighted one over the hemisphere (irradiance on level ground / pi)."""
    up = y > 0.0
    wc = w * np.maximum(y, 0.0)
    return {
        "hemisphere": (col[up] * w[up][:, None]).sum(0) / w[up].sum(),
        "sphere": (col * w[:, None]).sum(0) / w.sum(),
        "cosine": (col * wc[:, None]).sum(0) / wc.sum(),
    }


def _frame(axis):
    a = axis / np.linalg.norm(axis)
    helper = np.array([1.0, 0.0, 0.0]) if abs(a[0]) < 0.9 else np.array([0.0, 1.0, 0.0])
    t1 = np.cross(a, helper)
    t1 /= np.linalg.norm(t1)
    return a, t1, np.cross(a, t1)


def cap(axis, radius, rings, segs):
    """A polar grid over a spherical cap (midpoints, weights summing to its area)."""
    a, t1, t2 = _frame(axis)
    th = (np.arange(rings) + 0.5) / rings * radius
    ph = (np.arange(segs) + 0.5) / segs * TAU
    th, ph = [g.ravel() for g in np.meshgrid(th, ph, indexing="ij")]
    d = np.cos(th)[:, None] * a + np.sin(th)[:, None] * (np.cos(ph)[:, None] * t1 + np.sin(ph)[:, None] * t2)
    w = np.sin(th)
    w *= TAU * (1.0 - math.cos(radius)) / w.sum()
    return d, w


class Sphere:
    """A Fibonacci sphere, refined round the sun on demand."""

    def __init__(self, n):
        self.d = fibonacci(n)
        self.fbm = cloud_fbm(self.d)

    def around(self, sun, radius, rings, segs):
        out = self.d @ (sun / np.linalg.norm(sun)) < math.cos(radius)
        area = TAU * (1.0 - math.cos(radius))
        cd, cw = cap(sun, radius, rings, segs)
        d = np.concatenate([self.d[out], cd])
        w = np.concatenate([np.full(out.sum(), (4.0 * math.pi - area) / out.sum()), cw])
        return Dirs(d, w, np.concatenate([self.fbm[out], cloud_fbm(cd)]))


def band(elev_lo, elev_hi, azim, half_width, ne=12, na=31):
    """Directions over an elevation x azimuth window (degrees), weighted by solid angle."""
    e = np.radians(elev_lo + (np.arange(ne) + 0.5) / ne * (elev_hi - elev_lo))
    a = np.radians(azim - half_width + (np.arange(na) + 0.5) / na * 2.0 * half_width)
    e, a = [g.ravel() for g in np.meshgrid(e, a, indexing="ij")]
    d = np.stack([np.sin(a) * np.cos(e), np.sin(e), np.cos(a) * np.cos(e)], axis=-1)
    return Dirs(d, np.cos(e))


def zenith_cap(deg=10.0):
    d, w = cap(np.array([0.0, 1.0, 0.0]), math.radians(deg), 20, 64)
    return Dirs(d, w)


# --- the physical sky (PhysicalSky.SHADER) ------------------------------------------------

RG = 6360.0
RT = 6460.0
RAYLEIGH = np.array([5.802e-3, 13.558e-3, 33.1e-3])
MIE_SCATTER = 3.996e-3
MIE_EXTINCT = 8.396e-3
OZONE = np.array([0.650e-3, 1.881e-3, 0.085e-3])
EYE_HEIGHT = 0.3
GROUND_ALBEDO = np.array([0.09, 0.085, 0.06])
EYE = np.array([0.0, RG + EYE_HEIGHT, 0.0])


# The shader works with points p = o + d * t. Every quantity it takes from them is a
# function of three numbers, r^2 = |p|^2, p.l and t, so the port marches with those
# (|o + d t|^2 = |o|^2 + 2 t o.d + t^2) instead of 3-vectors: the same arithmetic,
# several times faster in numpy. Optical depth is linear in the three densities, so
# they are summed first and turned into RGB once.

def _sphere_far(r2, b, rad):
    """sphere(p, dir, rad).y given |p|^2 and p.dir; -1 on a miss."""
    h = b * b - (r2 - rad * rad)
    return np.where(h < 0.0, -1.0, -b + np.sqrt(np.maximum(h, 0.0)))


def _sphere_near(r2, b, rad):
    h = b * b - (r2 - rad * rad)
    return np.where(h < 0.0, -1.0, -b - np.sqrt(np.maximum(h, 0.0)))


def _density(h):
    """density(): air molecules, haze, ozone at a height (km), as three arrays."""
    return np.exp(-h / 8.0), np.exp(-h / 1.2), np.maximum(0.0, 1.0 - np.abs(h - 25.0) / 15.0)


def _rgb(nr, nm, no, turb):
    """extinction() of summed densities: (M,) x 3 -> (M, 3)."""
    return RAYLEIGH * nr[:, None] + (MIE_EXTINCT * turb) * nm[:, None] + OZONE * no[:, None]


def _sun_light(r2, pl, turb):
    """sun_light(p, l) given |p|^2 and p.l."""
    r = np.sqrt(r2)
    mu = pl / r
    # the earth's shadow, softened over the sun's own width
    horizon = -np.sqrt(np.maximum(0.0, 1.0 - (RG * RG) / r2))
    lit = smoothstep(horizon - 0.012, horizon + 0.004, mu)
    t = _sphere_far(r2, pl, RT)
    dt = t / 6.0
    sr = np.zeros_like(r)
    sm = np.zeros_like(r)
    so = np.zeros_like(r)
    for i in range(6):
        tq = (i + 0.5) * dt
        nr, nm, no = _density(np.sqrt(r2 + 2.0 * tq * pl + tq * tq) - RG)
        sr += nr * dt
        sm += nm * dt
        so += no * dt
    return np.exp(-_rgb(sr, sm, so, turb)) * np.where(lit > 0.0, lit, 0.0)[:, None]


class PhysicalSky:
    """sky() of PhysicalSky.SHADER. The march (everything before `energy`) runs once per
    sun and turbidity; color() then applies the energies, disc, clouds and pass."""

    def __init__(self, dirs, sun, turb):
        self.dirs = dirs
        self.turb = turb
        d = dirs.d
        l = sun + np.array([0.0, 1e-4, 0.0])
        l = l / np.linalg.norm(l)
        self.l = l
        o2 = EYE @ EYE
        od = d @ EYE  # o.d
        ol = EYE @ l  # o.l
        t_end = _sphere_far(o2, od, RT)
        tg = _sphere_near(o2, od, RG)
        ground = tg > 0.0
        t_end = np.where(ground, tg, t_end)
        mu = d @ l
        phase_r = 3.0 / (16.0 * math.pi) * (1.0 + mu * mu)
        g = 0.8
        phase_m = 3.0 / (8.0 * math.pi) * ((1.0 - g * g) * (1.0 + mu * mu)) / ((2.0 + g * g) * np.power(1.0 + g * g - 2.0 * g * mu, 1.5))
        lum_ = np.zeros_like(d)
        seen = np.ones_like(d)
        prev = np.zeros(len(d))
        n_steps = 16
        for i in range(n_steps):
            # samples crowd close in, where the air is thickest
            t1 = t_end * ((i + 1.0) / n_steps) ** 2
            dt = t1 - prev
            s_mid = prev + dt * 0.5
            prev = t1
            r2 = o2 + 2.0 * s_mid * od + s_mid * s_mid
            nr, nm, no = _density(np.sqrt(r2) - RG)
            ext = _rgb(nr, nm, no, turb)
            sr = RAYLEIGH * nr[:, None]
            sm = ((MIE_SCATTER * turb) * nm)[:, None]
            sun_l = _sun_light(r2, ol + s_mid * mu, turb)
            multi = (sr + sm) * (sun_l * 0.3 + 0.01) * (1.0 / (4.0 * math.pi))
            s = (sr * phase_r[:, None] + sm * phase_m[:, None]) * sun_l + multi
            through = np.exp(-ext * dt[:, None])
            # integrated over the step, not point-sampled (Hillaire 2015)
            lum_ += seen * (s - s * through) / np.maximum(ext, 1e-7)
            seen *= through
        if ground.any():
            tgr = t_end[ground]
            r2 = o2 + 2.0 * tgr * od[ground] + tgr * tgr
            pl = ol + tgr * mu[ground]
            lum_[ground] += seen[ground] * GROUND_ALBEDO / math.pi * _sun_light(r2, pl, turb) * np.maximum(pl / np.sqrt(r2), 0.0)[:, None]
        self.lum, self.seen, self.ground, self.mu = lum_, seen, ground, mu
        cloud_base = EYE + np.array([0.0, 2.0, 0.0])
        self.at_cloud = _sun_light(np.array([cloud_base @ cloud_base]), np.array([cloud_base @ l]), turb)[0]
        # what color() needs that no uniform changes: the disc's pixels and profile, the
        # cloud layer's directions and their silver lining
        r = np.arccos(np.clip(mu, -1.0, 1.0)) / 0.0087
        self.disc = np.nonzero((~ground) & (r < 1.0))[0]
        rr = r[self.disc]
        limb = 1.0 - 0.6 * (1.0 - np.sqrt(np.maximum(0.0, 1.0 - rr * rr)))
        self.disc_col = self.seen[self.disc] * (limb * 60.0 * smoothstep(1.0, 0.85, rr))[:, None]
        self.up = np.nonzero(d[:, 1] > 0.0)[0]
        self.silver = 0.35 + 0.9 * np.power(np.maximum(mu[self.up], 0.0), 6.0)
        self.horizon_fade = smoothstep(0.0, 0.2, d[self.up, 1])
        self._cover = {}

    def color(self, sky_energy, sun_energy, cloudiness, cubemap):
        energy = sun_energy
        col = self.lum * (energy * sky_energy)
        # the sun's disc, darker towards its limb, reddened by the air in front of it
        col[self.disc] += self.disc_col * (energy * 1.0 * (0.25 if cubemap else 1.0))  # sun_disk = 1
        up = self.up
        if cloudiness > 0.0 and len(up):
            # a thin layer of fair-weather cloud, lit by the sun as it reaches cloud height
            if cloudiness not in self._cover:
                self._cover[cloudiness] = smoothstep(1.0 - cloudiness - 0.15, 1.0 - cloudiness + 0.35, self.dirs.fbm[up]) * self.horizon_fade
            c = self._cover[cloudiness]
            at_cloud = self.at_cloud * energy
            cu = col[up]
            cl = at_cloud * self.silver[:, None] * 0.55 + cu * 0.45 + np.array([0.02, 0.025, 0.035]) * energy
            col[up] = mix(cu, cl, (c * 0.8)[:, None])
        if cubemap:
            grey = (col @ REC709)[:, None] * np.array([1.12, 1.0, 0.84])
            col = mix(col, grey, 0.45) * 1.2
        return col

    def means(self, sky_energy, sun_energy, cloudiness, cubemap):
        return self.dirs.means(self.color(sky_energy, sun_energy, cloudiness, cubemap))


def phys_dirs(sphere, sun):
    # the disc is 0.0087 rad in radius: a 0.02 rad patch, 40 rings deep
    return sphere.around(sun, 0.02, 40, 24)


# --- the painted sky (Atmosphere.SKY_SHADER) ---------------------------------------------

def painted_uniforms(mood):
    """What Atmosphere._build_env / apply_mood pass for a mood, made linear the way a
    source_color uniform is."""
    m = MOODS[mood]
    return {
        "zenith": srgb_to_linear(m["zenith"][:3]),
        "horizon": srgb_to_linear(m["horizon"][:3]),
        "ground_col": srgb_to_linear((0.24, 0.23, 0.2)),
        "sun_col": srgb_to_linear(m["sun"][:3]),
        "night_cloud": srgb_to_linear(linear_to_srgb((0.06, 0.06, 0.06))),
        "cloudiness": 1.0 if mood in ("overcast", "rain") else (0.3 if mood == "day" else 0.55),
        "stars": 1.0 if mood == "night" else 0.0,
    }


def painted_color(dirs, sun, u, clouds=True):
    """sky() of SKY_SHADER; clouds=False leaves the cloud layer out (for step 1's readings)."""
    d = dirs.d
    h = d[:, 1]
    zen, hor, sun_col = u["zenith"], u["horizon"], u["sun_col"]
    col = mix(hor, zen, np.sqrt(np.clip(h, 0.0, 1.0))[:, None])
    below = h < 0.0
    col[below] = mix(hor * 0.9, u["ground_col"], np.clip(-h[below] * 3.0, 0.0, 1.0)[:, None])
    sd = np.maximum(d @ sun, 0.0)  # LIGHT0_DIRECTION: toward the sun
    col += sun_col * (np.power(sd, 1200.0) * 40.0 + np.power(sd, 18.0) * 0.45 + np.power(sd, 3.0) * 0.12)[:, None]
    up = h > 0.0
    stars = u["stars"]
    if stars > 0.0:
        du = d[up]
        sd3 = (du / np.linalg.norm(du, axis=-1, keepdims=True)).astype(F32) * F32(420.0)
        cell = np.floor(sd3)
        sh = hash2(cell[:, 0] + cell[:, 2] * F32(17.13), cell[:, 1] + cell[:, 2] * F32(17.13))
        fp = fract(sd3) - F32(0.5)
        star = (sh >= 0.985) * smoothstep(0.32, 0.0, np.linalg.norm(fp.astype(np.float64), axis=-1))
        tw = 0.6  # 0.6 + 0.4 * sin(TIME * ...), on average
        col[up] += np.array([0.85, 0.9, 1.0]) * (star * tw * stars * 3.0 * smoothstep(0.0, 0.25, du[:, 1]))[:, None]
        bx = (du[:, 0] * 3.0 + du[:, 2]) * 2.0
        by = (du[:, 1] * 6.0) * 2.0
        bnd = fbm(bx, by)
        col[up] += np.array([0.04, 0.05, 0.08]) * (smoothstep(0.55, 0.9, bnd) * stars * smoothstep(0.1, 0.5, du[:, 1]))[:, None]
    if clouds:
        cloudiness = u["cloudiness"]
        c = smoothstep(1.0 - cloudiness - 0.15, 1.0 - cloudiness + 0.35, dirs.fbm[up]) * smoothstep(0.0, 0.2, h[up])
        cl = mix(hor * 0.95, mix(np.ones(3), u["night_cloud"], stars), 0.55) * (0.75 + 0.5 * sd[up])[:, None]
        cl = mix(cl, sun_col, (0.18 * sd[up])[:, None])
        col[up] = mix(col[up], cl, (c * 0.85)[:, None])
    return col


def painted_means(sphere, mood, clouds=True):
    sun = sun_dir(MOODS[mood]["elev"], MOODS[mood]["azim"])
    dirs = sphere.around(sun, 0.2, 120, 48)  # pow(sd, 1200) is ~0.03 rad wide
    return dirs.means(painted_color(dirs, sun, painted_uniforms(mood), clouds))


# --- the photographed sky (Atmosphere.PHOTO_SKY_SHADER) ----------------------------------

def read_hdr(path):
    """A Radiance RGBE file as Godot's loader decodes it: m * 2^(e - 128) / 255, linear."""
    with open(path, "rb") as f:
        data = f.read()
    pos = 0
    while True:
        end = data.index(b"\n", pos)
        line = data[pos:end]
        pos = end + 1
        if line == b"":
            break
        if line.startswith(b"FORMAT=") and line != b"FORMAT=32-bit_rle_rgbe":
            raise ValueError("unsupported HDR format %r" % line)
    end = data.index(b"\n", pos)
    res = data[pos:end].split()
    pos = end + 1
    if res[0] != b"-Y" or res[2] != b"+X":
        raise ValueError("unsupported HDR orientation %r" % res)
    h, w = int(res[1]), int(res[3])
    buf = np.frombuffer(data, dtype=np.uint8)
    out = np.empty((h, w, 4), dtype=np.uint8)
    for y in range(h):
        if data[pos] == 2 and data[pos + 1] == 2 and (data[pos + 2] << 8 | data[pos + 3]) == w:
            pos += 4
            for ch in range(4):
                row = out[y, :, ch]
                x = 0
                while x < w:
                    n = data[pos]
                    pos += 1
                    if n > 128:
                        n -= 128
                        row[x:x + n] = data[pos]
                        pos += 1
                    else:
                        row[x:x + n] = buf[pos:pos + n]
                        pos += n
                    x += n
        else:  # flat scanline
            out[y] = buf[pos:pos + 4 * w].reshape(w, 4)
            pos += 4 * w
    rgbe = out.astype(np.float64)
    return rgbe[..., :3] * (np.power(2.0, rgbe[..., 3] - 128.0) / 255.0)[..., None]


def photo_rotation(mood="day"):
    """Atmosphere._apply_sky(): Basis(Quaternion(lit, photographed)), the shortest arc
    turning the game's toward-sun direction onto the panorama's sun."""
    longitude = (1218.5 / 2048.0) * TAU
    latitude = (239.5 / 1024.0) * math.pi
    photographed = np.array([math.sin(longitude) * math.sin(latitude), math.cos(latitude), -math.cos(longitude) * math.sin(latitude)])
    lit = sun_dir(MOODS[mood]["elev"], MOODS[mood]["azim"])
    axis = np.cross(lit, photographed)
    s = np.linalg.norm(axis)
    angle = math.atan2(s, float(lit @ photographed))
    k = axis / s
    kx = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    rot = np.eye(3) + math.sin(angle) * kx + (1.0 - math.cos(angle)) * (kx @ kx)
    assert np.allclose(rot @ lit, photographed)
    return rot, lit


def photo_means(img, rot):
    """Integrated texel by texel (each texel's solid angle), so the clamped sun is counted
    as the panorama has it. The shader samples d = rotation * EYEDIR, so a texel seen in
    direction d is drawn at EYEDIR = rotation^T * d."""
    h, w = img.shape[:2]
    th = (np.arange(h) + 0.5) / h * math.pi
    lon = (np.arange(w) + 0.5) / w * TAU
    st, ct = np.sin(th)[:, None], np.cos(th)[:, None]
    dx, dy, dz = np.sin(lon)[None, :] * st, np.broadcast_to(ct, (h, w)), -np.cos(lon)[None, :] * st
    eye_y = dx * rot[0, 1] + dy * rot[1, 1] + dz * rot[2, 1]
    sky = np.minimum(img, 16.0)
    t = (1.0 - smoothstep(-0.20, -0.02, eye_y))[..., None]
    col = mix(sky, np.array([0.14, 0.16, 0.12]), t)
    wt = np.broadcast_to(st * (math.pi / h) * (TAU / w), (h, w))
    return weighted_means(col.reshape(-1, 3), wt.ravel(), eye_y.ravel())


# --- the report ----------------------------------------------------------------------

PASSES = (("cubemap", True), ("background", False))
CHANNELS = {"luminance": REC709, "R": np.array([1.0, 0, 0]), "G": np.array([0, 1.0, 0]), "B": np.array([0, 0, 1.0])}
CAL_MOODS = ["golden", "dawn", "dusk", "hazy"]
DUSK_ELEVS = (-2, -4, -6, -8, -10, -12)


def fmt(x):
    return "%.4g" % x


def rgb(v):
    return "(%s)" % ", ".join("%.4f" % c for c in v)


def gd_list(xs):
    return "[" + ", ".join("%.5g" % x for x in xs) + "]"


def gd_dict(d):
    return "{" + ", ".join("%s: %s" % (k, gd_list(v)) for k, v in d.items()) + "}"


# Every sun is marched on its own, so the suns go to a pool of processes, each with its
# own Fibonacci sphere. A task is (elev, azim, turbidity, requests) with each request
# (sky_energy, sun_energy, cloudiness, cubemap); it returns the means for each request.
_SPHERE = None


def _init_worker(n):
    global _SPHERE
    _SPHERE = Sphere(n)


def _march(task):
    elev, azim, turb, reqs = task
    sun = sun_dir(elev, azim)
    ph = PhysicalSky(phys_dirs(_SPHERE, sun), sun, turb)
    return [ph.means(*r) for r in reqs]


class Marcher:
    def __init__(self, n):
        self.n = n
        self.pool = None
        try:
            from concurrent.futures import ProcessPoolExecutor
            workers = max(1, min(12, (os.cpu_count() or 2) - 1))
            self.pool = ProcessPoolExecutor(max_workers=workers, initializer=_init_worker, initargs=(n,))
        except (ImportError, OSError, NotImplementedError):
            pass

    def run(self, tasks):
        if self.pool is not None:
            try:
                return list(self.pool.map(_march, tasks))
            except Exception as e:  # a broken pool: march here instead
                print("(the process pool failed, %s: marching in one process)" % e)
                self.pool = None
        if _SPHERE is None:
            _init_worker(self.n)
        return [_march(t) for t in tasks]

    def close(self):
        if self.pool is not None:
            self.pool.shutdown()


def step1(marcher, sphere_s):
    print("== Step 1: the port against PhysicalSky.MOODS' sky_energy ==")
    print("ratio  = painted mean / physical mean at sky_energy 1 (sun_energy = the mood's energy)")
    print("solved = the sky_energy that matches exactly: the physical sky is A * sky_energy + B, not")
    print("         proportional, since its sun disc and sunlit cloud tops do not scale with sky_energy")
    target = np.array([PHYS_MOODS[m][1] for m in CAL_MOODS])
    tasks = []
    for m in CAL_MOODS:
        turb, _, cloud = PHYS_MOODS[m]
        mm = MOODS[m]
        reqs = [(k, mm["energy"], cl, cube) for _, cube in PASSES for cl in (cloud, 0.0) for k in (0.0, 1.0)]
        tasks.append((mm["elev"], mm["azim"], turb, reqs))
    reads = {}
    for m, res in zip(CAL_MOODS, marcher.run(tasks)):
        r = {("painted", "drawn"): painted_means(sphere_s, m), ("painted", "left out"): painted_means(sphere_s, m, clouds=False)}
        it = iter(res)
        for pname, _ in PASSES:
            for cname in ("drawn", "left out"):
                r[(pname, cname, 0)] = next(it)
                r[(pname, cname, 1)] = next(it)
        reads[m] = r
    rows = []
    for dom in ("hemisphere", "sphere", "cosine"):
        for pname, _ in PASSES:
            for cname in ("drawn", "left out"):
                for mname, wv in CHANNELS.items():
                    p = np.array([reads[m][("painted", cname)][dom] @ wv for m in CAL_MOODS])
                    b = np.array([reads[m][(pname, cname, 0)][dom] @ wv for m in CAL_MOODS])
                    k1 = np.array([reads[m][(pname, cname, 1)][dom] @ wv for m in CAL_MOODS])
                    for meth, vals in (("ratio", p / k1), ("solved", (p - b) / (k1 - b))):
                        err = vals / target - 1.0
                        main = dom != "cosine" and cname == "drawn"
                        rows.append((np.abs(err).max(), main, dom, pname, cname, mname, meth, vals, err))
    rows.sort(key=lambda r: r[0])

    def show(r):
        cells = "  ".join("%5.2f %+5.0f%%" % (v, 100 * e) for v, e in zip(r[7], r[8]))
        print("%-10s %-10s %-9s %-6s  %s   %5.1f%%" % (r[2], r[3], r[5], r[6], cells, 100 * r[0]))

    head = "  ".join("%-12s" % ("%s %.1f" % (m, t)) for m, t in zip(CAL_MOODS, target))
    print()
    print("%-10s %-10s %-9s %-6s  %s worst" % ("domain", "pass", "metric", "method", head))
    for r in rows:
        if r[1]:
            show(r)
    print()
    print("other readings (cosine = irradiance-weighted hemisphere; clouds left out of both skies), best six:")
    print("%-10s %-10s %-9s %-6s  %s worst  clouds" % ("domain", "pass", "metric", "method", head))
    for r in [r for r in rows if not r[1]][:6]:
        cells = "  ".join("%5.2f %+5.0f%%" % (v, 100 * e) for v, e in zip(r[7], r[8]))
        print("%-10s %-10s %-9s %-6s  %s   %5.1f%%  %s" % (r[2], r[3], r[5], r[6], cells, 100 * r[0], r[4]))
    best = next(r for r in rows if r[1])
    print()
    if best[0] <= 0.15:
        print("VALIDATED: %s mean, %s pass, %s, %s reproduces the game's sky_energy within %.0f%%" % (best[2], best[3], best[5], best[6], 100 * best[0]))
    else:
        print("NOT VALIDATED: no averaging reproduces the game's sky_energy within 15%%; the closest, %s mean, %s pass, %s, %s, is %.0f%% off"
            % (best[2], best[3], best[5], best[6], 100 * best[0]))
        main = [r for r in rows if r[1]]
        more = sum(1 for r in main if r[7][1] > r[7][0] and r[7][2] > r[7][0])
        print("(in %d of the %d readings above, dawn and dusk need more sky_energy than golden; the game gives them less)" % (more, len(main)))
    dom, pas = best[2], best[3]
    print()
    print("behind it, %s means (linear luminance):  painted   physical B   physical A (per sky_energy)   at the game's sky_energy" % dom)
    for m, t in zip(CAL_MOODS, target):
        r = reads[m]
        p = lum(r[("painted", "drawn")][dom])
        b = lum(r[(pas, "drawn", 0)][dom])
        a = lum(r[(pas, "drawn", 1)][dom]) - b
        print("  %-8s %10s %12s %12s %18s (%+.0f%% of painted)" % (m, fmt(p), fmt(b), fmt(a), fmt(a * t + b), 100 * ((a * t + b) / p - 1)))
    print()
    return dom, pas, {m: reads[m][("painted", "drawn")] for m in CAL_MOODS}


def step2(marcher, sphere_s, img, dom, pas, painted_done):
    cube = pas == "cubemap"
    other = "background" if cube else "cubemap"
    print("== Step 2: tables, %s means (the closest averaging in step 1), %s pass first ==" % (dom, pas))
    print("(Rec.709 luminance of linear RGB; per unit sun_energy unless said; the shaders are linear in sun_energy)")
    print()

    # 1. the physical sky against the sun's elevation
    elevs = list(range(-14, 63, 2))
    turbs = [1.6, 1.9, 2.4]
    clouds = [0.3, 0.45, 0.5]
    passes = [(pas, cube), (other, not cube)]
    reqs = [(k, 1.0, c, cb) for _, cb in passes for c in clouds for k in (0.0, 1.0)]
    tasks = [(e, 0.0, t, reqs) for t in turbs for e in elevs]
    A = {(p, t, c): [] for p, _ in passes for t in turbs for c in clouds}
    B = {key: [] for key in A}
    for (_, _, t, _), res in zip(tasks, marcher.run(tasks)):
        it = iter(res)
        for pname, _ in passes:
            for c in clouds:
                b = lum(next(it)[dom])
                A[(pname, t, c)].append(lum(next(it)[dom]) - b)
                B[(pname, t, c)].append(b)
    print("1. Physical sky: mean luminance = (A * sky_energy + B) * sun_energy; cloudiness 0.45, sun azimuth 0, %s pass" % pas)
    print("   total = A + B, the mean at sky_energy 1 and sun_energy 1. B is the sunlit cloud tops, the sun's disc and")
    print("   the cloud layer's own glow (0.02-0.035 x sun_energy), which is all that is left of B with the sun down.")
    print("elev " + "".join("| turb %-3s  total      A          B         " % t for t in turbs))
    for i, e in enumerate(elevs):
        print("%4d " % e + "".join("|           %-10s %-10s %-10s" % (fmt(A[(pas, t, 0.45)][i] + B[(pas, t, 0.45)][i]), fmt(A[(pas, t, 0.45)][i]), fmt(B[(pas, t, 0.45)][i])) for t in turbs))
    sun_up = [i for i, e in enumerate(elevs) if e >= 2]
    spread = max(abs(A[(pas, 2.4, 0.45)][i] / A[(pas, 1.6, 0.45)][i] - 1) for i in sun_up)
    print("turbidity 1.6 -> 2.4 moves A by at most %.1f%% with the sun 2 deg up or more" % (100 * spread))
    for k in (1.0, 6.0):
        up, down = [], []
        for i, e in enumerate(elevs):
            lo = A[(pas, 1.9, 0.3)][i] * k + B[(pas, 1.9, 0.3)][i]
            hi = A[(pas, 1.9, 0.5)][i] * k + B[(pas, 1.9, 0.5)][i]
            (up if e >= 2 else down).append(hi / lo - 1.0)
        print("cloudiness 0.5 vs 0.3 (turbidity 1.9, sky_energy %g): %+.0f%% to %+.0f%% with the sun 2 deg up or more, %+.0f%% to %+.0f%% below that"
            % (k, 100 * min(up), 100 * max(up), 100 * min(down), 100 * max(down)))
    ra = [A[(pas, 1.9, 0.5)][i] / A[(pas, 1.9, 0.3)][i] for i in sun_up]
    rb = [B[(pas, 1.9, 0.5)][i] / B[(pas, 1.9, 0.3)][i] for i in sun_up]
    print("   (A at 0.5 / A at 0.3: %.3f to %.3f; B at 0.5 / B at 0.3: %.2f to %.2f, sun up)" % (min(ra), max(ra), min(rb), max(rb)))
    tasks = [(e, a, 1.9, [(6.0, 1.0, 0.45, cube)]) for e in (4.0, 24.0) for a in (0.0, 90.0, 180.0, 270.0)]
    v = np.array([lum(r[0][dom]) for r in marcher.run(tasks)]).reshape(2, 4)
    az = v.max(1) / v.min(1) - 1.0
    print("the sun's azimuth (0/90/180/270) moves the mean by %.1f%% (elev 4) and %.1f%% (elev 24): only the fixed cloud pattern turns" % (100 * az[0], 100 * az[1]))
    print()
    print("# Physical sky, %s mean luminance = (A * sky_energy + B) * sun_energy, sun azimuth 0" % dom)
    print("const PHYS_ELEV := %s" % gd_list(elevs))
    for pname, _ in passes:
        sfx = "" if pname == pas else "_" + pname.upper()
        print("# %s pass, cloudiness 0.45, by turbidity" % pname)
        print("const PHYS_A%s := %s" % (sfx, gd_dict({t: A[(pname, t, 0.45)] for t in turbs})))
        print("const PHYS_B%s := %s" % (sfx, gd_dict({t: B[(pname, t, 0.45)] for t in turbs})))
    print("# %s pass, turbidity 1.9, by cloudiness" % pas)
    print("const PHYS_A_BY_CLOUD := %s" % gd_dict({c: A[(pas, 1.9, c)] for c in clouds}))
    print("const PHYS_B_BY_CLOUD := %s" % gd_dict({c: B[(pas, 1.9, c)] for c in clouds}))
    print()

    # 2. the painted sky per mood
    print("2. Painted sky, mean luminance per mood (the same in both passes)")
    painted = {}
    for m in ["day", "golden", "dawn", "dusk", "night", "hazy", "overcast", "rain"]:
        hs = painted_done.get(m) or painted_means(sphere_s, m)
        painted[m] = hs
        print("  %-9s %-9s (hemisphere %-9s sphere %-9s cosine %-9s)  RGB %s" % (m, fmt(lum(hs[dom])), fmt(lum(hs["hemisphere"])), fmt(lum(hs["sphere"])), fmt(lum(hs["cosine"])), rgb(hs[dom])))
    print("const PAINTED_LUM := {%s}" % ", ".join('"%s": %.5g' % (m, lum(v[dom])) for m, v in painted.items()))
    print()

    # 3. the photo against the physical sky under midday's sun
    day = MOODS["day"]
    rot, _ = photo_rotation("day")
    pm = photo_means(img, rot)
    pl = lum(pm[dom])
    res = marcher.run([(day["elev"], day["azim"], 1.6, [(k, day["energy"], 0.3, cb) for _, cb in passes for k in (0.0, 1.0)])])[0]
    print("3. Midday: the photo sky against the physical sky (elev %g, azim %g, sun_energy %g, turbidity 1.6, cloudiness 0.3)" % (day["elev"], day["azim"], day["energy"]))
    print("  photo sky        %-9s (hemisphere %s, sphere %s, cosine %s)  RGB %s" % (fmt(pl), fmt(lum(pm["hemisphere"])), fmt(lum(pm["sphere"])), fmt(lum(pm["cosine"])), rgb(pm[dom])))
    for j, (pname, _) in enumerate(passes):
        b = lum(res[2 * j][dom])
        k1 = res[2 * j + 1][dom]
        a = lum(k1) - b
        print("  physical, %-10s pass, sky_energy 1: %-9s = A %s x sky_energy + B %s  RGB %s" % (pname, fmt(a + b), fmt(a), fmt(b), rgb(k1)))
        print("      sky_energy matching the photo: %.3g   (plain ratio photo / sky_energy-1 mean: %.3g)" % ((pl - b) / a, pl / (a + b)))
    print("  painted day for reference: %s" % fmt(lum(painted["day"][dom])))
    print()

    # 4. the dusk sky continued below the horizon
    dusk = MOODS["dusk"]
    az = dusk["azim"]
    zc = zenith_cap()
    toward = band(2.0, 8.0, az, 15.0)
    away = band(2.0, 8.0, az + 180.0, 15.0)
    print("4. The physical dusk sky below the horizon: sky_energy 6.1, sun_energy 1.9, turbidity 1.9, cloudiness 0.4, azimuth %g" % az)
    print("   linear RGB; zenith = mean over the cap above 80 deg; horizon = elevation 2-8 deg within 15 deg of the")
    print("   sun's azimuth or the opposite one; dome = %s mean" % dom)
    looks = [(pas, cube, 0.4), (other, not cube, 0.4), (pas, cube, 0.0)]
    domes = marcher.run([(e, az, 1.9, [(6.1, 1.9, cl, cb) for _, cb, cl in looks]) for e in DUSK_ELEVS])
    for j, (pname, cb, cl) in enumerate(looks):
        if j == 2:
            print("%s pass with cloudiness 0 (the cloud layer's own glow is most of what the dome keeps once the sun is down)" % pname)
        else:
            print("%s pass" % pname)
        print("elev   zenith                    horizon toward sun        horizon away from sun     dome                      dome lum")
        for e, dres in zip(DUSK_ELEVS, domes):
            sun = sun_dir(e, az)
            v = [PhysicalSky(ds, sun, 1.9).means(6.1, 1.9, cl, cb)["sphere"] for ds in (zc, toward, away)]
            dome = dres[j][dom]
            print("%4d   %s  %s  %s  %s  %s" % (e, rgb(v[0]), rgb(v[1]), rgb(v[2]), rgb(dome), fmt(lum(dome))))
    night = MOODS["night"]
    nu = painted_uniforms("night")
    moon = sun_dir(night["elev"], night["azim"])
    nv = [ds.means(painted_color(ds, moon, nu))["sphere"] for ds in (zc, band(2.0, 8.0, night["azim"], 15.0), band(2.0, 8.0, night["azim"] + 180.0, 15.0))]
    nd = painted["night"][dom]
    print("painted night, the same measures (toward / away from its moon at elev %g, azim %g):" % (night["elev"], night["azim"]))
    print("       %s  %s  %s  %s  %s" % (rgb(nv[0]), rgb(nv[1]), rgb(nv[2]), rgb(nd), fmt(lum(nd))))
    print("painted night's own gradient, linear: zenith %s, horizon %s" % (rgb(nu["zenith"]), rgb(nu["horizon"])))
    # where the physical dusk dome falls to the painted night's
    es = np.arange(-2.0, 6.01, 1.0)
    dl = np.array([lum(r[0][dom]) for r in marcher.run([(e, az, 1.9, [(6.1, 1.9, 0.4, cube)]) for e in es])])
    target = lum(nd)
    i = np.nonzero((dl[:-1] - target) * (dl[1:] - target) <= 0)[0]
    print("physical dusk dome luminance (%s pass) at sun elevation %s: %s" % (pas, ", ".join("%g" % e for e in es), ", ".join(fmt(x) for x in dl)))
    if len(i):
        j = i[0]
        e0 = es[j] + (target - dl[j]) / (dl[j + 1] - dl[j]) * (es[j + 1] - es[j])
        print("it falls to the painted night's dome mean (%s) at sun elevation %.1f deg" % (fmt(target), e0))
    else:
        print("it never crosses the painted night's dome mean (%s) between -2 and 6 deg" % fmt(target))


def main():
    t0 = time.time()
    check_ports()
    marcher = Marcher(N_PHYS)
    try:
        sphere_s = Sphere(N_PAINT)
        img = read_hdr(HDR)
        peak = np.unravel_index(np.argmax(lum(img)), img.shape[:2])
        if (peak[1], peak[0]) != (1218, 239):
            print("WARNING: the panorama's brightest texel is at %s, not (1218, 239) as _apply_sky assumes" % ((peak[1], peak[0]),))
        dom, pas, painted = step1(marcher, sphere_s)
        step2(marcher, sphere_s, img, dom, pas, painted)
    finally:
        marcher.close()
    print()
    print("(%.0f s)" % (time.time() - t0))


if __name__ == "__main__":
    main()
