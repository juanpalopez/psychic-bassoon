"""A larger mock board (24 x 16 cells) with winding roads, for the look-dev only. Same
conventions as the game's export: Godot world x across, z towards the camera; sockets are 2x2
blocks [col, row, level]; routes as world (x, z) points every 0.25 m."""
import json, math, os, random

HERE = os.path.dirname(os.path.abspath(__file__))

COLS, ROWS = 24, 16


def catmull(ctrl, step=0.25):
    pts = []
    for i in range(len(ctrl) - 1):
        p0 = ctrl[max(0, i - 1)]; p1 = ctrl[i]; p2 = ctrl[i + 1]; p3 = ctrl[min(len(ctrl) - 1, i + 2)]
        seg = math.dist(p1, p2)
        n = max(2, int(seg / step * 1.2))
        for k in range(n):
            t = k / n; t2 = t * t; t3 = t2 * t
            pts.append(tuple(0.5 * ((2 * p1[d]) + (-p0[d] + p2[d]) * t + (2 * p0[d] - 5 * p1[d] + 4 * p2[d] - p3[d]) * t2 + (-p0[d] + 3 * p1[d] - 3 * p2[d] + p3[d]) * t3) for d in (0, 1)))
    pts.append(ctrl[-1])
    # resample evenly
    out = [pts[0]]
    acc = 0.0
    for a, b in zip(pts, pts[1:]):
        d = math.dist(a, b)
        while acc + d >= step:
            t = (step - acc) / d
            a = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            out.append(a)
            d = math.dist(a, b)
            acc = 0.0
        acc += d
    out.append(pts[-1])
    return out


# main road: in from the west, winding across, to the Heartstone in the east
R0 = [(-13.5, -2.5), (-10.0, -4.2), (-7.0, -2.0), (-7.6, 2.6), (-4.0, 5.2), (0.2, 3.6), (-0.4, -0.8),
      (2.6, -4.6), (6.6, -3.6), (6.4, 1.2), (9.0, 4.8), (11.4, 1.4), (10.4, -4.6)]
# second road: down from the north, joining the main one
R1_HEAD = [(-3.4, -8.8), (-3.8, -6.2), (-2.6, -3.8), (-1.0, -2.4)]
# the river runs down the middle of the valley, north to south (Blender y = -z)
RIVER_Z = [(5.0, -40.0), (4.8, -18.0), (4.5, -9.0), (4.4, -4.2), (3.8, -1.0), (3.7, 3.0), (3.4, 8.0), (2.5, 14.0), (1.0, 30.0)]


def build(seed=4):
    rng = random.Random(seed)
    r0 = catmull(R0)
    # join index: the r0 point nearest the end of r1's head
    j = min(range(len(r0)), key=lambda i: math.dist(r0[i], R1_HEAD[-1]))
    r1 = catmull(R1_HEAD + [r0[j + 6]]) + r0[j + 7:]
    river = catmull(RIVER_Z, 0.5)
    hs_cell = (int(round(10.4 + COLS / 2 - 1.0)), int(round(-4.6 + ROWS / 2 - 1.0)))

    def cell_centre(c, r):  # centre of a 2x2 block with top-left cell (c, r)
        return (c - (COLS - 1) / 2 + 0.5, r - (ROWS - 1) / 2 + 0.5)

    def clear(c, r, extra=0.0):
        x, z = cell_centre(c, r)
        if not (0 <= c <= COLS - 2 and 0 <= r <= ROWS - 2):
            return False
        for p in r0 + r1:
            if abs(p[0] - x) < 1.0 + 0.55 + extra and abs(p[1] - z) < 1.0 + 0.55 + extra:
                return False
        for p in river:
            if math.dist(p, (x, z)) < 3.6:
                return False
        hx, hz = cell_centre(*hs_cell)
        return abs(hx - x) > 2.5 or abs(hz - z) > 2.5

    sockets = []
    for k in range(8, len(r0) - 6, 6):
        a, b = r0[k - 1], r0[k + 1]
        tx, tz = b[0] - a[0], b[1] - a[1]
        L = math.hypot(tx, tz)
        nx, nz = -tz / L, tx / L
        for side in ((1, -1) if (k // 6) % 2 else (-1, 1)):
            x = r0[k][0] + nx * side * 2.3
            z = r0[k][1] + nz * side * 2.3
            c = int(math.floor(x + (COLS - 1) / 2 - 0.5 + 0.5))
            r = int(math.floor(z + (ROWS - 1) / 2 - 0.5 + 0.5))
            if clear(c, r) and all(abs(c - s[0]) > 2 or abs(r - s[1]) > 2 for s in sockets):
                lvl = rng.choices([0, 1, 2], [6, 3, 1])[0]
                sockets.append([c, r, lvl])
                break
    return {"seed": seed, "cols": COLS, "rows": ROWS, "footprint": 2, "sockets": sockets,
            "heartstone": [hs_cell[0], hs_cell[1], 2, 2], "routes_world": [r0, r1],
            "river_world": river}


if __name__ == "__main__":
    b = build()
    json.dump(b, open(os.path.join(HERE, "board_large.json"), "w"))
    print(len(b["sockets"]), "sockets;", len(b["routes_world"][0]), "pts")
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(10, 7))
    for r, c in zip(b["routes_world"], ("tab:brown", "tab:orange")):
        ax.plot([p[0] for p in r], [p[1] for p in r], c, lw=6, alpha=0.6)
    ax.plot([p[0] for p in b["river_world"]], [p[1] for p in b["river_world"]], "tab:blue", lw=10, alpha=0.4)
    for c_, r_, l in b["sockets"]:
        x, z = c_ - (COLS - 1) / 2 - 0.5, r_ - (ROWS - 1) / 2 - 0.5
        ax.add_patch(plt.Rectangle((x, z), 2, 2, color=["green", "olive", "purple"][l], alpha=0.6))
    hc = b["heartstone"]
    ax.add_patch(plt.Rectangle((hc[0] - (COLS - 1) / 2 - 0.5, hc[1] - (ROWS - 1) / 2 - 0.5), 2, 2, color="red"))
    ax.add_patch(plt.Rectangle((-COLS / 2, -ROWS / 2), COLS, ROWS, fill=False))
    ax.set_xlim(-15, 15); ax.set_ylim(-11, 11); ax.invert_yaxis(); ax.set_aspect("equal"); ax.grid(alpha=0.3)
    plt.savefig(os.path.join(HERE, "board_large.png"), dpi=80)
