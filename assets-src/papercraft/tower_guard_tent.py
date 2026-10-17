
# tower_guard_tent.py - The Guard Tent: a folded origami A-frame tent in striped paper on
# a kraft ground sheet, pegged out with thread guy-lines and sewing pins, with a cardboard
# shield and a toothpick spear by the door. Parts: Base (tent, sheet, pins, shield, pole),
# Door (the curtain over the doorway; rolls up when the guards come out) and Flag (the
# paper pennant on the pole; flutters).

GT_RIDGE = 1.25
GT_HALF_X = 0.72
GT_HALF_Y = 0.64


def face_out(p, cos, col, out, mat="PK_PaperVC", smooth=False):
    """A face whose normal points along `out` (both sides: the back darker)."""
    cos = [Vector(c) for c in cos]
    n = (cos[1] - cos[0]).cross(cos[2] - cos[0])
    if n.dot(Vector(out)) < 0:
        cos.reverse()
    p.face(cos, col, mat, smooth=smooth)
    # the back side sits a sheet's thickness behind, so the two faces stay apart
    n = (cos[1] - cos[0]).cross(cos[2] - cos[0]).normalized() * 0.004
    p.face([v - n for v in reversed(cos)], shade(col, 0.42), mat, smooth=smooth)


def build_guard_tent(c, at):
    RED = lin("#c23b3b"); CREAM = lin("#f1e4c6"); KRAFT = lin("#c79d6d"); THREAD = lin("#e9e2d2")
    STEEL = lin("#c9cdd3"); PICK = lin("#f0dcae"); GOLD = lin("#efc23e"); CARD = lin("#a98b66")
    BLUE = lin("#3567a8"); SHADOW = lin("#3a2a26")
    HX, HY, RZ = GT_HALF_X, GT_HALF_Y, GT_RIDGE
    CZ = 0.56; CX = 0.47   # the mid-height crease of each side panel (folded out)
    Z0 = 0.012

    b = Part("GuardTent_Base")
    # the kraft ground sheet, a little skewed, with a turned-up corner
    sheet = [(-0.78, -0.77), (0.8, -0.75), (0.77, 0.79), (-0.75, 0.76)]
    b.slab(sheet, 0.006, KRAFT, shade(KRAFT, 0.85))
    # the two side panels, in stripes running from the ridge down, creased at mid-height
    strips = 8
    for s in (-1, 1):
        for k in range(strips):
            y0 = -HY + 2 * HY * k / strips; y1 = -HY + 2 * HY * (k + 1) / strips
            col = RED if k % 2 == 0 else CREAM
            low = [(s * HX, y0, Z0), (s * HX, y1, Z0), (s * CX, y1, CZ), (s * CX, y0, CZ)]
            up = [(s * CX, y0, CZ), (s * CX, y1, CZ), (0, y1, RZ), (0, y0, RZ)]
            face_out(b, low, col, (s, 0, 0.3))
            face_out(b, up, shade(col, 1.04), (s, 0, 0.8))
    # the back gable, closed
    back = [(-HX, HY, Z0), (HX, HY, Z0), (CX, HY, CZ), (0, HY, RZ), (-CX, HY, CZ)]
    face_out(b, back, CREAM, (0, 1, 0))
    # the front gable either side of the doorway
    DX, DZ = 0.30, 0.95
    for s in (-1, 1):
        g = [(s * HX, -HY, Z0), (s * DX, -HY, Z0), (0, -HY, DZ), (0, -HY, RZ), (s * CX, -HY, CZ)]
        face_out(b, g, CREAM, (0, -1, 0))
    # the dark inside seen through the door
    b.face([(-DX * 0.95, -HY + 0.25, Z0 + 0.002), (DX * 0.95, -HY + 0.25, Z0 + 0.002), (0, -HY + 0.25, DZ * 0.95)], SHADOW)
    b.face([(DX * 0.95, -HY + 0.25, Z0 + 0.002), (-DX * 0.95, -HY + 0.25, Z0 + 0.002), (0, -HY + 0.25, DZ * 0.95)], SHADOW)
    # guy-lines from the ridge ends to sewing pins in the mat
    pins = [(-0.74, -0.76, BLUE), (0.74, -0.76, GOLD), (-0.74, 0.76, GOLD), (0.74, 0.76, BLUE)]
    for (px, py, col) in pins:
        top = Vector((0, py * HY / abs(py) * 1.0, RZ - 0.02))
        pin_head = Vector((px, py, 0.17))
        b.tube([top, top.lerp(pin_head, 0.5) + Vector((0, 0, -0.04)), pin_head], 0.006, 4, THREAD, caps=False)
        b.tube([(px * 0.98, py * 0.98, -0.02), (px, py, 0.16)], 0.008, 5, STEEL, "PK_MetalVC")
        b.sphere((px, py, 0.18), 0.04, 8, 5, col)
    # the flag pole: a toothpick through the ridge
    b.tube([(0, 0, RZ - 0.05), (0, 0, RZ + 0.62), (0, 0, RZ + 0.66)], [0.014, 0.012, 0.001], 6, PICK, "PK_WoodVC", caps=False)
    # the right curtain, folded back against the gable and tied with thread
    face_out(b, [(0.0, -HY - 0.02, DZ), (DX + 0.02, -HY - 0.02, Z0), (DX + 0.2, -HY - 0.02, Z0 + 0.05), (0.14, -HY - 0.02, 0.6)],
             CREAM, (0, -1, 0))
    face_out(b, [(DX + 0.02, -HY - 0.024, Z0), (DX + 0.2, -HY - 0.024, Z0 + 0.05), (DX + 0.19, -HY - 0.024, Z0 + 0.11), (DX + 0.0, -HY - 0.024, Z0 + 0.07)],
             RED, (0, -1, 0))
    b.tube([(DX + 0.24, -HY - 0.03, 0.36), (DX + 0.12, -HY - 0.045, 0.40), (DX - 0.02, -HY - 0.03, 0.44)], 0.009, 4, RED, "PK_ThreadVC", caps=False)
    # a cardboard shield and a toothpick spear leaning by the door, at the front left
    shield = [(-0.17, 0.44), (0.17, 0.44)] + [(0.17 * math.cos(-a), 0.18 + 0.19 * math.sin(-a))
                                               for a in [math.pi * k / 8 for k in range(0, 9)]]
    SM = Matrix.Translation((-0.56, -0.72, 0.0)) @ Matrix.Rotation(math.radians(20), 4, "Z") @ \
        Matrix.Rotation(math.radians(-8), 4, "X")
    F = SM @ frame((0, 0, 0), (1, 0, 0), (0, 0, 1)) @ Matrix.Translation((0, 0.0, 0))
    b.slab(shield, 0.03, CARD, shade(CARD, 0.8), M=F, edge_mat="PK_Corrugated")
    FM = F @ Matrix.Translation((0, 0, 0.031))
    b.slab([(-0.035, 0.43), (0.035, 0.43), (0.035, 0.0), (-0.035, 0.0)], 0.002, RED, M=FM)
    b.slab([(-0.16, 0.31), (0.16, 0.31), (0.16, 0.24), (-0.16, 0.24)], 0.002, RED, M=FM)
    b.tube([(-0.40, -0.66, 0.0), (-0.70, -0.77, 1.05)], 0.013, 6, PICK, "PK_WoodVC")
    b.tube([(-0.70, -0.77, 1.05), (-0.725, -0.78, 1.14), (-0.73, -0.785, 1.17)], [0.032, 0.02, 0.001], 4, STEEL, "PK_MetalVC", caps=False)
    base = rest(b.build(c, at))

    # ---------------- Door: the left curtain, hung from the top of the doorway ----------------
    d = Part("GuardTent_Door")
    top = DZ + 0.02
    tri = [(-DX - 0.02, 0, -top), (0.03, 0, -top), (0, 0, 0)]
    face_out(d, tri, CREAM, (0, -1, 0))
    face_out(d, [(-DX - 0.02, -0.003, -top), (0.03, -0.003, -top), (0.025, -0.003, -top + 0.07), (-DX + 0.0, -0.003, -top + 0.07)], RED, (0, -1, 0))
    face_out(d, [(-0.005, -0.003, -top), (0.03, -0.003, -top), (0.0, -0.003, 0.0), (-0.012, -0.003, -0.02)], RED, (0, -1, 0))
    door = rest(d.build(c, (0, -HY - 0.015, top), base))

    # ---------------- Flag: the pennant ----------------
    f = Part("GuardTent_Flag")
    face_out(f, [(0, 0, 0), (0.24, 0, -0.045), (0.24, 0, -0.165), (0, 0, -0.21)], GOLD, (0, -1, 0))
    face_out(f, [(0.24, 0, -0.045), (0.46, 0, -0.105), (0.24, 0, -0.165)], GOLD, (0, -1, 0))
    face_out(f, [(0.02, -0.002, -0.08), (0.30, -0.002, -0.095), (0.30, -0.002, -0.115), (0.02, -0.002, -0.13)], RED, (0, -1, 0))
    flag = rest(f.build(c, (0.012, 0, RZ + 0.6), base))
    return {"GuardTent_Base": base, "GuardTent_Door": door, "GuardTent_Flag": flag}


def anim_guard_tent():
    T = "guard_tent"
    CLIPS[T] = [("idle", 24, True), ("deploy", 12, False)]
    track(T, "idle", "GuardTent_Flag",
          [(f, None, (0, 0, 20.0 * math.sin(math.tau * f / 12)), (0.85 + 0.15 * math.sin(math.tau * f / 8 + 1), 1, 1))
           for f in range(24)])
    track(T, "idle", "GuardTent_Door", [(f, None, (3.0 * math.sin(math.tau * f / 24), 0, 0), None) for f in range(24)])
    track(T, "deploy", "GuardTent_Door", [
        (0, None, None, None), (1, None, (-14, 0, 0), (1, 1, 0.55)), (2, None, (-22, 0, 0), (1, 1, 0.2)),
        (3, None, (-24, 0, 0), (1, 1, 0.08)), (9, None, (-16, 0, 0), (1, 1, 0.4)), (10, None, (-6, 0, 0), (1, 1, 0.8)),
        (11, None, None, None)])
    track(T, "deploy", "GuardTent_Flag", [(f, None, (0, 0, 22.0 * math.sin(math.tau * f / 6)), None) for f in range(12)])
