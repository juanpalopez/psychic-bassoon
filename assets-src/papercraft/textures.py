"""Seamless textures for the papercraft shaders (godot/render/paper/).

Run inside Blender (it saves through bpy):  blender -b -P assets-src/papercraft/textures.py
Writes godot/assets/textures/paper/paper_noise.png (RGBA: fibre, blotch, speck, crinkle) and
mat_cuts.png (healed cut marks). Noise is white noise filtered in frequency space, so it is
periodic and tiles without seams; the cut marks are drawn with wrap-around.
"""
import os
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "godot", "assets", "textures", "paper"))
N = 512
rng = np.random.default_rng(20261016)
k = np.fft.fftfreq(N) * N
KX, KY = np.meshgrid(k, k)


def periodic(fx, fy):
    w = rng.standard_normal((N, N))
    v = np.real(np.fft.ifft2(np.fft.fft2(w) * np.exp(-((KX / fx) ** 2 + (KY / fy) ** 2))))
    v -= v.min()
    return v / v.max()


def fbm(base, octaves=4):
    out, amp, tot = np.zeros((N, N)), 1.0, 0.0
    for o in range(octaves):
        out += amp * periodic(base * 2 ** o, base * 2 ** o)
        tot += amp
        amp *= 0.5
    return out / tot


def norm(v, lo=1, hi=99):
    a, b = np.percentile(v, [lo, hi])
    return np.clip((v - a) / (b - a), 0, 1)


def save(name, arr):
    if arr.ndim == 2:
        arr = np.dstack([arr, arr, arr, np.ones_like(arr)])
    img = bpy.data.images.new(name, N, N, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels[:] = arr[::-1].astype(np.float32).ravel()
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def main():
    os.makedirs(OUT, exist_ok=True)
    fibre = norm(periodic(6, 70) * 0.6 + periodic(14, 140) * 0.4)
    blotch = norm(fbm(3, 4))
    speck = np.clip((norm(periodic(120, 120)) - 0.72) / 0.12, 0, 1)
    speck = 0.5 * norm(fbm(40, 3)) + 0.5 * speck
    crinkle = norm(periodic(10, 40) * 0.5 + fbm(8, 3) * 0.5)
    save("paper_noise", np.dstack([fibre, blotch, speck, crinkle]))
    cuts = np.zeros((N, N))
    yy, xx = np.mgrid[0:N, 0:N]
    for _ in range(70):
        x0, y0 = rng.uniform(0, N, 2)
        ang, length = rng.uniform(0, np.pi), rng.uniform(40, 260)
        dx, dy = np.cos(ang), np.sin(ang)
        inten, width = rng.uniform(0.35, 1.0), rng.uniform(0.5, 1.1)
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                px, py = xx - (x0 + ox), yy - (y0 + oy)
                t = np.clip(px * dx + py * dy, 0, length)
                d = np.hypot(px - t * dx, py - t * dy)
                cuts = np.maximum(cuts, inten * np.clip(1 - d / width, 0, 1) * (1 - 0.6 * (t / length)))
    save("mat_cuts", np.clip(cuts, 0, 1))


main()
