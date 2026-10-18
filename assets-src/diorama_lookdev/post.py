"""Post for the diorama look-dev: what Godot's Environment can add after the scene (written for the
Compatibility renderer; Forward+ and Mobile can do all of it, Forward+ adds SSAO and volumetric fog).
Reads a Blender multilayer EXR (linear Combined + Depth) and applies, in order:
  depth fog (exponential, Environment fog), glow (Environment glow: bright parts blurred and
  added), ACES tonemap (Environment tonemap), grading (Environment adjustments: brightness,
  contrast, saturation, plus a warm/cool split that a colour-correction LUT can do), and an
  optional tilt-shift blur by depth (a cheap full-screen pass; its cost needs checking on a phone).
usage: python3 post.py in.exr out.png [camera.json] [--dof]"""
import sys
import numpy as np
import OpenEXR
from PIL import Image, ImageFilter


def load(path):
    f = OpenEXR.File(path)
    parts = f.parts
    ch = {}
    for p in parts:
        for name, c in p.channels.items():
            ch[name] = c.pixels
    return ch


def pick(ch, *names):
    for n in names:
        for k in ch:
            if k.endswith(n):
                return ch[k]
    raise KeyError(names, list(ch)[:20])


def blur(a, r):
    if r <= 0.3:
        return a
    from scipy.ndimage import gaussian_filter
    return gaussian_filter(a, sigma=(r, r, 0), mode="nearest")


def aces(x):
    a, b, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
    return np.clip((x * (a * x + b)) / (x * (c * x + d) + e), 0, 1)


def to_srgb(x):
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(np.clip(x, 0, None), 1 / 2.4) - 0.055)


def run(src, dst, dof=False, fog_col=(0.78, 0.74, 0.70), fog_start=18.0, fog_density=0.018,
        exposure=1.0, glow_thr=1.2, glow_mix=0.18, sat=1.12, contrast=1.06, warm=0.05, focus=None,
        cam=None, height_ref=-0.6, height_range=2.8, height_amount=0.55, height_col=(0.62, 0.52, 0.42),
        sky_col=(0.45, 0.6, 0.85), dof_strength=3.2):
    ch = load(src)
    comb = ch["ViewLayer.Combined"]
    rgb = comb[..., :3] if comb.ndim == 3 else comb
    z = ch["ViewLayer.Depth.Z"].astype(np.float32)
    z = np.where(np.isfinite(z) & (z < 1e5), z, 1e3)
    rgb = rgb.astype(np.float32) * exposure
    # depth fog, as Godot's: amount = 1 - exp(-density * (depth - start))
    f = 1.0 - np.exp(-fog_density * np.clip(z - fog_start, 0, None))
    f = np.clip(f, 0, 0.92)[..., None]
    fog = np.array(fog_col, np.float32)
    rgb = rgb * (1 - f) + fog * f
    # height fog: haze settling in the canyons (Godot's Environment height fog)
    if cam is not None:
        h, w = z.shape
        tan = np.tan(cam["fov_y"] / 2)
        asp = w / h
        u = (np.arange(w) + 0.5) / w * 2 - 1
        v = 1 - (np.arange(h) + 0.5) / h * 2
        U, V = np.meshgrid(u, v)
        dcam = np.stack([U * tan * asp, V * tan, -np.ones_like(U)], -1)
        R = np.array(cam["rot"], np.float32)
        wpos = np.array(cam["loc"], np.float32) + (dcam * z[..., None]) @ R.T
        wz = wpos[..., 2]
        fh = np.clip((height_ref - wz) / height_range, 0, 1) * height_amount
        fh = np.where(z > 900, 0, fh)[..., None]
        rgb = rgb * (1 - fh) + np.array(height_col, np.float32) * fh
        # the sky: a gradient from a warm haze at the horizon to a soft blue above
        updir = (dcam / np.linalg.norm(dcam, axis=-1, keepdims=True)) @ R.T
        sky_t = np.clip(updir[..., 2] * 3.0, 0, 1)[..., None]
        sky = np.array(fog_col, np.float32) * (1 - sky_t) + np.array(sky_col, np.float32) * sky_t
        rgb = np.where((z > 900)[..., None], sky, rgb)
    # glow
    bright = np.clip(rgb - glow_thr, 0, None)
    g = blur(bright, 6) * 0.6 + blur(bright, 18) * 0.4
    rgb = rgb + g * glow_mix * 4
    # tonemap and grade
    out = aces(rgb)
    lum = (out @ np.array([0.2126, 0.7152, 0.0722], np.float32))[..., None]
    out = lum + (out - lum) * sat
    out = (out - 0.5) * contrast + 0.5
    # split toning: warm highlights, cool shadows
    out = out + warm * np.concatenate([lum, lum * 0.4, -lum * 0.6], -1) - warm * 0.5 * np.concatenate([(1 - lum) * 0.0, (1 - lum) * 0.0, -(1 - lum) * 0.5], -1)
    out = np.clip(out, 0, 1)
    out = to_srgb(out)
    if dof:
        h = out.shape[0]
        if focus is None:
            focus = float(np.median(z[int(h * 0.45):int(h * 0.75), :]))
        cocz = np.abs(1.0 / np.maximum(z, 0.1) - 1.0 / focus) * focus
        coc = np.clip((cocz - 0.12) * dof_strength, 0, 1)
        b1 = blur(out, 1.6)
        b2 = blur(out, 4.0)
        c = coc[..., None]
        out = np.where(c < 0.5, out * (1 - 2 * c) + b1 * 2 * c, b1 * (2 - 2 * c) + b2 * (2 * c - 1))
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(dst)
    return {"zmin": float(z.min()), "zmed": float(np.median(z)), "zmax": float(z[z < 999].max() if (z < 999).any() else 0)}


if __name__ == "__main__":
    import json
    cam = json.load(open(sys.argv[3])) if len(sys.argv) > 3 and sys.argv[3].endswith(".json") else None
    print(run(sys.argv[1], sys.argv[2], dof="--dof" in sys.argv, cam=cam))
