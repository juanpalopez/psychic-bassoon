
# tower_spool_guard.py - The Spool Guard: a wooden thread spool carrying a lolly-stick
# ballista on a shirt button, firing rolled paper-strip darts. Parts: Base (the spool),
# Head (button turntable, stock, toothpick bow, drawn string; turns to aim) and Dart
# (the loaded dart; flies off and is reloaded). Exec'd in towers_hd.py's namespace.

SG_SCALE = 1.25      # the ballista on the button, against the spool
SG_PITCH = -6.0      # the stock's pitch (front up)


def build_spool_guard(c, at):
    WOOD = lin("#eadbc0"); WOOD_E = lin("#cdb48e"); HOLE = lin("#3a2818")
    RED = lin("#c43238"); RED_D = lin("#97222a")
    CREAM = lin("#f3e7c9"); INK = lin("#3b3330")
    BTN = lin("#2f6c8e"); BTN_L = lin("#4f92b6"); BTN_H = lin("#132f3e")
    STICK = lin("#ecd3a2"); PICK = lin("#f0dcae"); TAPE = lin("#d2bd8f")
    PAPER = lin("#f6f2e8"); PRINT = lin("#8d8a84"); FLETCH = lin("#d6403c"); TIP = lin("#55575c")
    NEWS = lin("#ddd6c4"); STEEL = lin("#c9cdd3")

    # ---------------- Base: the spool ----------------
    b = Part("SpoolGuard_Base")
    b.lathe([(0.0, 0.0), (0.60, 0.0), (0.66, 0.035), (0.66, 0.10), (0.61, 0.135), (0.42, 0.145)], 20, WOOD,
            "PK_WoodVC", colf=lambda j, i, a: WOOD_E if j in (1, 2, 3) else WOOD)
    # wound thread: a slight bulge; the windings are drawn by the thread shader
    N = 6; z0, z1 = 0.145, 0.855
    prof = [(0.40 + 0.026 * math.sin(math.pi * k / N), z0 + (z1 - z0) * k / N) for k in range(N + 1)]
    b.lathe(prof, 20, RED, "PK_ThreadVC")
    b.lathe([(0.42, 0.855), (0.61, 0.865), (0.66, 0.90), (0.66, 0.965), (0.60, 1.0), (0.10, 1.0),
             (0.085, 0.985), (0.085, 0.93), (0.0, 0.93)], 20, WOOD, "PK_WoodVC",
            colf=lambda j, i, a: HOLE if j >= 5 else (WOOD_E if j in (1, 2, 3) else WOOD))
    # the printed paper label on the top flange: a red rim, a cream band with print
    def label(j, i, a):
        if j == 0:
            return RED
        if j == 1:
            return INK if (i % 3 == 0 and -0.4 < math.sin(a)) else CREAM
        return CREAM
    b.lathe([(0.60, 1.003), (0.565, 1.003), (0.47, 1.003), (0.36, 1.003)], 24, CREAM, colf=label, smooth=False)
    # a loose thread end trailing onto the mat
    pts = []
    for k in range(14):
        t = k / 13.0
        r = 0.425 + 0.36 * t + 0.02 * math.sin(t * 9)
        z = max(0.012, 0.5 * (1 - t) ** 1.6) if r > 0.66 or z_ok(r, t) else 0.5
        a = math.radians(-48) + 0.6 * t * t
        pts.append((r * math.cos(a), r * math.sin(a), z))
    b.tube(pts, 0.011, 6, RED, "PK_ThreadVC")
    # a sewing pin stuck in the thread
    a = math.radians(150)
    out = Vector((math.cos(a), math.sin(a), 0.0))
    b.tube([out * 0.30 + Vector((0, 0, 0.5)), out * 0.62 + Vector((0, 0, 0.68))], 0.008, 6, STEEL, "PK_MetalVC")
    b.sphere(out * 0.64 + Vector((0, 0, 0.69)), 0.04, 10, 6, lin("#e2b23a"))
    base = rest(b.build(c, at))

    # ---------------- Head: button, stock, bow ----------------
    h = Part("SpoolGuard_Head")
    h.lathe([(0.0, 0.0), (0.31, 0.0), (0.33, 0.02), (0.33, 0.045), (0.30, 0.062), (0.26, 0.062),
             (0.25, 0.05), (0.0, 0.05)], 16, BTN, colf=lambda j, i, a: BTN_L if j in (2, 3, 4) else BTN)
    for sx in (-1, 1):
        for sy in (-1, 1):
            h.disc(0.03, 0.0505, 10, BTN_H, M=Matrix.Translation((0.085 * sx, 0.085 * sy, 0)))
    G = Matrix.Translation((0, 0.08, 0.05)) @ Matrix.Scale(SG_SCALE, 4) @ Matrix.Translation((0, 0, -0.05))
    # lolly-stick uprights and the toothpick axle
    arc = [(0.04 * math.cos(math.pi * k / 6), 0.33 + 0.04 * math.sin(math.pi * k / 6)) for k in range(7)]
    up = [(-0.04, 0.05), (0.04, 0.05), (0.04, 0.33)] + arc[1:-1] + [(-0.04, 0.33)]
    for x in (0.12, -0.14):
        h.slab(up, 0.02, STICK, shade(STICK, 0.85), "PK_WoodVC", M=G @ frame((x, 0, 0), (0, 1, 0), (0, 0, 1)))
    h.tube([G @ Vector(p) for p in [(-0.21, 0, 0.33), (-0.18, 0, 0.33), (0.18, 0, 0.33), (0.21, 0, 0.33)]],
           [0.001, 0.011 * SG_SCALE, 0.011 * SG_SCALE, 0.001], 6, PICK, "PK_WoodVC", caps=False)
    # the stock: a lolly stick pitched up a little, on the axle
    P = G @ Matrix.Translation((0, 0, 0.345)) @ Matrix.Rotation(math.radians(SG_PITCH), 4, "X")
    L0, L1, W = -0.62, 0.42, 0.045
    front = [(W * math.cos(math.pi + math.pi * k / 6), L0 + W + W * math.sin(math.pi + math.pi * k / 6)) for k in range(7)]
    back = [(W * math.cos(math.pi * k / 6), L1 - W + W * math.sin(math.pi * k / 6)) for k in range(7)]
    h.slab(front + back, 0.022, STICK, shade(STICK, 0.85), "PK_WoodVC", M=P)
    # the white paper rail the dart lies in
    h.box((-0.026, -0.56, 0.022), (0.026, 0.12, 0.026), PAPER, shade(PAPER, 0.9), M=P)
    h.box((-0.030, -0.56, 0.022), (-0.024, 0.12, 0.040), PAPER, shade(PAPER, 0.88), M=P)
    h.box((0.024, -0.56, 0.022), (0.030, 0.12, 0.040), PAPER, shade(PAPER, 0.88), M=P)
    # masking tape wrapped round the grip
    h.box((-0.05, 0.2, -0.004), (0.05, 0.29, 0.027), TAPE, shade(TAPE, 0.86), M=P)
    # toothpick bow limbs, bound to the stock with red thread
    BZ = 0.034; BY = -0.50
    for s in (-1, 1):
        pts = [(s * 0.02, BY - 0.005, BZ), (s * 0.15, BY - 0.02, BZ + 0.004), (s * 0.30, BY + 0.0, BZ + 0.01),
               (s * 0.44, BY + 0.07, BZ + 0.016), (s * 0.47, BY + 0.10, BZ + 0.018)]
        h.tube([P @ Vector(p) for p in pts], [r * SG_SCALE for r in (0.015, 0.014, 0.012, 0.008, 0.002)], 6,
               PICK, "PK_WoodVC", caps=False)
    h.tube([P @ Vector((-0.06, BY, BZ)), P @ Vector((0.06, BY, BZ))], 0.03 * SG_SCALE, 10, RED, "PK_ThreadVC")
    # the drawn string (cotton) from the limb tips to the nock
    NOCK = Vector((0.0, -0.02, 0.036))
    for s in (-1, 1):
        h.tube([P @ Vector((s * 0.465, BY + 0.095, BZ + 0.018)), P @ NOCK], 0.007, 5, PAPER)
    # a rolled-newspaper quiver with spare darts
    Q = G @ Matrix.Translation((0.2, 0.16, 0.06))
    h.lathe([(0.05, 0.0), (0.05, 0.24), (0.044, 0.24), (0.044, 0.02)], 10, NEWS, M=Q,
            colf=lambda j, i, a: PRINT if (i % 4 == 0 and j == 0) else NEWS)
    for k, (dx, dy) in enumerate([(-0.015, 0.01), (0.015, 0.012), (0.0, -0.016)]):
        p0 = Q @ Vector((dx, dy, 0.16)); p1 = Q @ Vector((dx * 3, dy * 3, 0.32))
        h.tube([p0, p1], 0.012, 5, PAPER)
        h.slab([(0.0, 0.0), (0.08, 0.0), (0.0, 0.045)], 0.003, FLETCH, M=frame(p1, (0, 0, -1), (1, 0.3 * k, 0)))
    head = rest(h.build(c, (0, 0, 1.0), base))

    # ---------------- Dart: the loaded dart, on its own pivot at the nock ----------------
    d = Part("SpoolGuard_Dart")
    S = SG_SCALE; R = 0.014 * S
    shaft = [(0.0, -0.55 * S * k / 6, 0.0) for k in range(7)]
    d.tube(shaft, R, 8, PAPER, colf=lambda k, i: PRINT if (k + i) % 4 == 0 else PAPER, caps=False)
    d.disc(R, 0.0, 8, PAPER, up=False, M=Matrix.Rotation(math.radians(-90), 4, "X"))
    d.tube([(0, -0.55 * S, 0), (0, -0.60 * S, 0), (0, -0.65 * S, 0)], [R, 0.008 * S, 0.0005], 8, TIP,
           "PK_MetalVC", caps=False)
    for k in range(3):
        ang = math.radians(90 + 120 * k)
        radial = Vector((math.cos(ang), 0.0, math.sin(ang)))
        M = frame(radial * R, (0, -1, 0), radial) @ Matrix.Translation((0, 0, -0.0015))
        d.slab([(0.0, 0.0), (0.15 * S, 0.0), (0.0, 0.065 * S)], 0.003, FLETCH, M=M)
    nock = P @ NOCK
    dart = d.build(c, nock + Vector((0, 0, 0.012 * S)), head)
    dart.rotation_euler = (math.radians(SG_PITCH), 0, 0)
    rest(dart)
    return {"SpoolGuard_Base": base, "SpoolGuard_Head": head, "SpoolGuard_Dart": dart}


def z_ok(r, t):
    return t > 0.25


def anim_spool_guard():
    T = "spool_guard"
    CLIPS[T] = [("idle", 24, True), ("fire", 12, False)]
    track(T, "idle", "SpoolGuard_Head", [(f, None, (0, 0, 11.0 * math.sin(math.tau * f / 24)), None) for f in range(24)])
    track(T, "idle", "SpoolGuard_Dart", [(0, None, None, None)])
    # fire: the dart flies off along the stock, the head kicks back, a new dart drops in
    th = math.radians(-SG_PITCH)
    fwd = Vector((0, -math.cos(th), math.sin(th)))
    track(T, "fire", "SpoolGuard_Dart", [
        (0, None, None, None),
        (1, tuple(fwd * 0.5), None, None),
        (2, tuple(fwd * 1.3), None, (0.001, 0.001, 0.001)),
        (6, (0, 0.06, 0.24), None, (1, 1, 1)),
        (7, (0, 0.03, 0.1), None, None),
        (8, (0, 0, 0.02), None, None),
        (9, None, None, None)])
    track(T, "fire", "SpoolGuard_Head", [
        (0, None, None, None), (1, (0, 0.07, 0), None, None), (2, (0, 0.045, 0), None, None),
        (3, (0, 0.015, 0), None, None), (4, None, None, None)])
