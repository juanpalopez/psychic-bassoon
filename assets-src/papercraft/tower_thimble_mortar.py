
# tower_thimble_mortar.py - The Thimble Mortar: a dimpled metal thimble on a matchstick
# trunnion between two corrugated cardboard cheeks, turning on a copper coin over a
# stacked cardboard drum, with paper pellets and an open matchbox of "powder".
# Parts: Base (drum, pellets, matchbox), Head (coin, cheeks, matchstick axle; turns to aim)
# and Barrel (the thimble with a pellet in its mouth; thumps when it fires).

TM_TILT = 48.0   # the thimble leans forward from upright, degrees
TM_S = 1.3       # the thimble and its cheeks, against the drum


def build_thimble_mortar(c, at):
    KRAFT = lin("#c49a6c"); KRAFT_D = lin("#a77d52"); CARD = lin("#b88a5c")
    STEEL = lin("#dcc278"); STEEL_IN = lin("#4a3f2a"); NEWS = lin("#ded7c5"); CREAM = lin("#efe6cf")
    COPPER = lin("#c27b4c"); COPPER_D = lin("#8f532f"); MATCH = lin("#e9d2a6"); HEAD = lin("#c83a2e")
    BOX = lin("#2f5596"); BOX_S = lin("#d64a3c"); BOX_IN = lin("#e6d3ad"); PENCIL = lin("#3b3833")
    DIMPLE = lambda col: (col[0], col[1], col[2], 1.0)

    # ---------------- Base: a drum of three cardboard discs ----------------
    b = Part("ThimbleMortar_Base")
    side = [1, 3, 5]
    b.lathe([(0.0, 0.0), (0.62, 0.0), (0.62, 0.066), (0.612, 0.069), (0.612, 0.131), (0.62, 0.134),
             (0.62, 0.20), (0.45, 0.20), (0.44, 0.20), (0.0, 0.20)], 20, KRAFT,
            colf=None, uv_scale=1.0, smooth=False)
    # recolour/remat the drum sides as corrugated board (rebuilt below with the material)
    b.bm.free(); b = Part("ThimbleMortar_Base")
    b.lathe([(0.0, 0.0), (0.62, 0.0)], 20, CARD, smooth=False)
    b.lathe([(0.62, 0.0), (0.62, 0.066)], 20, CARD, "PK_Corrugated", uv_scale=1.0)
    b.lathe([(0.62, 0.066), (0.612, 0.069), (0.612, 0.131), (0.62, 0.134)], 20, KRAFT_D, uv_scale=1.0)
    b.lathe([(0.62, 0.134), (0.62, 0.20)], 20, CARD, "PK_Corrugated", uv_scale=1.0)
    b.lathe([(0.62, 0.20), (0.455, 0.20), (0.44, 0.20), (0.0, 0.20)], 20, KRAFT,
            colf=lambda j, i, a: PENCIL if j == 1 else KRAFT, smooth=False)
    # paper pellets piled at the back left
    for k, (x, y, z, r) in enumerate([(-0.40, 0.30, 0.27, 0.075), (-0.27, 0.40, 0.27, 0.07), (-0.47, 0.15, 0.27, 0.07),
                                      (-0.33, 0.24, 0.27, 0.072), (-0.38, 0.30, 0.38, 0.07), (-0.30, 0.34, 0.37, 0.065)]):
        b.crumple((x, y, z), r, NEWS if k % 2 else CREAM, seed=k + 3)
    # a half-open matchbox at the back right: the sleeve, the drawer and its match heads
    M = Matrix.Translation((0.36, 0.34, 0.20)) @ Matrix.Rotation(math.radians(-28), 4, "Z")
    b.box((-0.11, -0.065, 0.0), (0.11, 0.065, 0.07), BOX, M=M,
          colf=lambda n: BOX_S if n[0] != 0 else (BOX if n[2] >= 0 else BOX))
    Dm = M @ Matrix.Translation((0.13, 0.0, 0.004))
    b.box((-0.10, -0.06, 0.0), (0.10, 0.06, 0.012), BOX_IN, M=Dm)
    b.box((-0.10, -0.06, 0.0), (-0.092, 0.06, 0.06), BOX_IN, M=Dm)
    b.box((0.092, -0.06, 0.0), (0.10, 0.06, 0.06), BOX_IN, M=Dm)
    for k in range(5):
        y = -0.045 + 0.0225 * k
        b.box((-0.085, y - 0.007, 0.012), (0.06, y + 0.007, 0.026), MATCH, mat="PK_WoodVC", M=Dm)
        b.box((0.06, y - 0.009, 0.010), (0.088, y + 0.009, 0.03), HEAD, M=Dm)
    base = rest(b.build(c, at))

    # ---------------- Head: copper coin, cheeks, matchstick axle ----------------
    h = Part("ThimbleMortar_Head")
    h.lathe([(0.0, 0.0), (0.40, 0.0), (0.405, 0.012), (0.40, 0.03), (0.37, 0.03), (0.365, 0.026),
             (0.31, 0.026), (0.305, 0.03), (0.0, 0.03)], 20, COPPER, "PK_MetalVC",
            colf=lambda j, i, a: COPPER_D if j in (5,) else COPPER, smooth=False)
    TZ = 0.47 * TM_S
    cheek = [(-0.34, 0.03), (0.34, 0.03), (0.17 * TM_S, TZ - 0.02)]
    cheek += [(0.13 * TM_S * math.cos(math.radians(a)), TZ + 0.13 * TM_S * math.sin(math.radians(a))) for a in range(0, 181, 30)]
    cheek += [(-0.22 * TM_S, TZ - 0.04)]
    for x in (0.258 * TM_S, -0.258 * TM_S - 0.045):
        F = frame((x, 0, 0), (0, 1, 0), (0, 0, 1))
        h.slab(cheek, 0.045, KRAFT, CARD, M=F, edge_mat="PK_Corrugated")
    # the matchstick axle with a red head at one end
    h.box((-0.44, -0.014, TZ - 0.014), (0.41, 0.014, TZ + 0.014), MATCH, mat="PK_WoodVC")
    h.sphere((0.44, 0.0, TZ), 0.032, 8, 6, HEAD, sx=1.4)
    # glue blobs where the cheeks meet the coin
    for x in (0.30 * TM_S, -0.30 * TM_S):
        h.sphere((x, 0.0, 0.035), 0.05, 8, 4, (0.92, 0.9, 0.82, 0.0), sz=0.25, sy=4.5)
    head = rest(h.build(c, (0, 0, 0.20), base))

    # ---------------- Barrel: the thimble ----------------
    t = Part("ThimbleMortar_Barrel")
    prof = [(0.0, -0.24), (0.07, -0.233), (0.13, -0.21), (0.175, -0.17), (0.20, -0.115), (0.21, -0.05),
            (0.215, 0.05), (0.222, 0.16), (0.228, 0.24), (0.231, 0.27), (0.234, 0.30), (0.25, 0.31),
            (0.253, 0.33), (0.243, 0.345), (0.21, 0.343), (0.205, 0.30), (0.19, 0.0)]
    prof = [(r * TM_S, z * TM_S) for r, z in prof]
    def tcol(j, i, a):
        if j <= 8:
            return DIMPLE(STEEL)
        if j <= 13:
            return STEEL
        return STEEL_IN
    t.lathe(prof, 20, STEEL, "PK_MetalVC", colf=tcol)
    t.disc(0.19 * TM_S, 0.0, 16, STEEL_IN, mat="PK_MetalVC")
    t.crumple((0.0, 0.0, 0.22 * TM_S), 0.14 * TM_S, NEWS, seed=21, segs=8, rings=6)
    barrel = t.build(c, (0, 0, TZ), head)
    barrel.rotation_euler = (math.radians(TM_TILT), 0, 0)
    rest(barrel)
    return {"ThimbleMortar_Base": base, "ThimbleMortar_Head": head, "ThimbleMortar_Barrel": barrel}


def anim_thimble_mortar():
    T = "thimble_mortar"
    CLIPS[T] = [("idle", 24, True), ("fire", 12, False)]
    track(T, "idle", "ThimbleMortar_Head", [(f, None, (0, 0, 6.0 * math.sin(math.tau * f / 24)), None) for f in range(24)])
    track(T, "idle", "ThimbleMortar_Barrel", [(f, None, (1.5 * math.sin(math.tau * f / 12), 0, 0), None) for f in range(24)])
    ax = Vector((0, -math.sin(math.radians(TM_TILT)), math.cos(math.radians(TM_TILT))))
    track(T, "fire", "ThimbleMortar_Barrel", [
        (0, None, None, None),
        (1, tuple(ax * -0.06), (-4, 0, 0), (1.08, 1.08, 0.80)),
        (2, tuple(ax * 0.035), (2, 0, 0), (0.93, 0.93, 1.14)),
        (3, tuple(ax * -0.01), None, (1.03, 1.03, 0.96)),
        (4, None, None, None)])
    track(T, "fire", "ThimbleMortar_Head", [
        (0, None, None, None), (1, (0, 0.04, -0.012), None, None), (2, (0, 0.02, 0), None, None),
        (3, None, None, None)])
