# diorama_lookdev.py - look-dev of a boundless papercraft diorama for Papercraft Kingdom Defense.
# Builds the seed-1 board (board_seed1.json, exported from the game) as an irregular cardboard
# plateau with corrugated cliffs, the road as a torn kraft-paper path, socket blocks as mesas,
# and a surround of plateaus, a foil-river canyon, rope bridges, paper trees and d20 rocks that
# runs out to a hazy horizon. Lit only with what Godot's Compatibility renderer can do: one sun
# with soft shadows, a flat sky fill, colours with the creases baked in (vertex colour), and depth
# fog, glow and grading added afterwards from the depth pass. (Written while the game still targeted
# the web; the game now uses Forward+ and Mobile, see docs/art/STYLE.md.)
# Blender: X = Godot x, Y = -Godot z, Z = up. 1 unit = 1 cell = 1 m. Run inside Blender 5.2.
#
# This file is a library of functions, run from Blender's Python console; it has no main and
# builds nothing on its own. The mock in docs/art/diorama/ was made in roughly this order (the
# exact arguments of each render were tuned by hand and not recorded; each render saves its
# camera next to it as renders/<name>_cam.json):
#   import os; os.environ["PKD_ROOT"] = "<path to your checkout>"
#   exec(open(os.environ["PKD_ROOT"] + "/assets-src/diorama_lookdev/diorama_lookdev.py").read())
#   use_board("board_large.json"); build_world2(); stage_units()
#   light_and_camera(...); save_camera("v15_game"); render("v15_game")
# then, outside Blender: python3 post.py renders/v15_game.exr out.png renders/v15_game_cam.json --dof
# It loads the desk GLBs from godot/assets/models (decor_pins, decor_scrap), which the diorama
# scatter (#326) replaces. Renders go to renders/ (ignored by git).
import bpy, bmesh, math, random, json, os
from mathutils import Vector, noise, Matrix

# The repo root: from PKD_ROOT, or two folders up from this script (run it with
# `blender --python assets-src/diorama_lookdev/diorama_lookdev.py` from a checkout).
try:
    _HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:  # exec() from Blender's console has no __file__: set PKD_ROOT first
    _HERE = os.path.join(os.environ.get("PKD_ROOT", os.getcwd()), "assets-src", "diorama_lookdev")
ROOT = os.environ.get("PKD_ROOT") or os.path.abspath(os.path.join(_HERE, "..", ".."))
HERE = ROOT + "/assets-src/diorama_lookdev"
MODELS = ROOT + "/godot/assets/models"
B = json.load(open(HERE + "/board_seed1.json"))
COLS, ROWS, FP = B["cols"], B["rows"], B["footprint"]
LEVEL_H = [0.0, 1.0, 2.0]
CANYON_Z = -3.2
rng = random.Random(11)


def use_board(name):
    """Swaps the board the look-dev builds (board_seed1.json is the game's; board_large.json is
    the 24 x 16 mock with winding roads)."""
    global B, COLS, ROWS, FP
    B = json.load(open(HERE + "/" + name))
    COLS, ROWS, FP = B["cols"], B["rows"], B["footprint"]


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def g2b(x, z, y=0.0):
    return Vector((x, -z, y))


def cell_c(col, row):
    return g2b(col - (COLS - 1) / 2, row - (ROWS - 1) / 2)


# ---------------------------------------------------------------- scene + collections
def fresh_scene():
    sc = bpy.data.scenes.get("Diorama")
    if sc is None:
        sc = bpy.data.scenes.new("Diorama")
    bpy.context.window.scene = sc
    for o in list(sc.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(sc.collection.children):
        bpy.data.collections.remove(c)
    return sc


def coll(name):
    sc = bpy.context.scene
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    if c.name not in sc.collection.children:
        sc.collection.children.link(c)
    return c


# ---------------------------------------------------------------- materials
def vc_mat(name, rough=0.85, metal=0.0, spec=0.25, emit=None):
    """A material that is just the vertex colour (like the game's craft_vc), with optional
    procedural fibre noise for paper, so the mock uses only what the game shader can do."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = 38.0
    tex.inputs["Detail"].default_value = 6.0
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs[3].default_value = 0.9
    mr.inputs[4].default_value = 1.08
    nt.links.new(tex.outputs["Fac"], mr.inputs[0])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    nt.links.new(vc.outputs["Color"], mul.inputs[6])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    for i in range(3):
        nt.links.new(mr.outputs[0], comb.inputs[i])
    nt.links.new(comb.outputs[0], mul.inputs[7])
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    patch = nt.nodes.new("ShaderNodeTexNoise")
    patch.inputs["Scale"].default_value = 0.22
    patch.inputs["Detail"].default_value = 3.0
    nt.links.new(geo.outputs["Position"], patch.inputs["Vector"])
    pr = nt.nodes.new("ShaderNodeMapRange")
    pr.inputs[1].default_value = 0.35
    pr.inputs[2].default_value = 0.65
    pr.inputs[3].default_value = 0.86
    pr.inputs[4].default_value = 1.1
    nt.links.new(patch.outputs["Fac"], pr.inputs[0])
    mul2 = nt.nodes.new("ShaderNodeMix")
    mul2.data_type = "RGBA"
    mul2.blend_type = "MULTIPLY"
    mul2.inputs[0].default_value = 1.0
    nt.links.new(mul.outputs[2], mul2.inputs[6])
    comb2 = nt.nodes.new("ShaderNodeCombineXYZ")
    for i in range(3):
        nt.links.new(pr.outputs[0], comb2.inputs[i])
    nt.links.new(comb2.outputs[0], mul2.inputs[7])
    nt.links.new(mul2.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Specular IOR Level"].default_value = spec
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = 1.0
    nt.links.new(b.outputs[0], out.inputs[0])
    return m


MATS = {}


def add_crinkle(m, scale=2.2, strength=0.55):
    """Crumpled foil: a bump from Voronoi-ish noise (the game shader can do the same from a
    noise texture; no tangents needed for a world-space bump)."""
    nt = m.node_tree
    b = [n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"][0]
    tex = nt.nodes.new("ShaderNodeTexVoronoi")
    tex.inputs["Scale"].default_value = scale
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    nt.links.new(tex.outputs["Distance"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])


def add_bump(m, scale_xyz, strength, distance=0.05, detail=4.0, scale=1.0):
    """A world-space procedural bump (stretched noise): vertical grain on the cliffs, fibre on
    the grass. A Godot shader can do the same from a noise texture and the screen derivatives."""
    nt = m.node_tree
    b = [n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"][0]
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mp = nt.nodes.new("ShaderNodeVectorMath")
    mp.operation = "MULTIPLY"
    mp.inputs[1].default_value = scale_xyz
    nt.links.new(geo.outputs["Position"], mp.inputs[0])
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = scale
    tex.inputs["Detail"].default_value = detail
    nt.links.new(mp.outputs[0], tex.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = distance
    nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])


def add_cobbles(m, scale=3.2):
    """Cobbles of packed card: Voronoi edges a little darker and pressed in."""
    nt = m.node_tree
    b = [n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"][0]
    base = b.inputs["Base Color"].links[0].from_socket
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = scale
    nt.links.new(geo.outputs["Position"], vor.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs[1].default_value = 0.0
    mr.inputs[2].default_value = 0.08
    mr.inputs[3].default_value = 0.72
    mr.inputs[4].default_value = 1.0
    nt.links.new(vor.outputs["Distance"], mr.inputs[0])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    nt.links.new(base, mul.inputs[6])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    for i in range(3):
        nt.links.new(mr.outputs[0], comb.inputs[i])
    nt.links.new(comb.outputs[0], mul.inputs[7])
    nt.links.new(mul.outputs[2], b.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.6
    bump.inputs["Distance"].default_value = 0.02
    nt.links.new(mr.outputs[0], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])


def make_materials():
    MATS["paper"] = vc_mat("DIO_paper")
    MATS["cliff"] = vc_mat("DIO_cliff", rough=0.9)
    add_bump(MATS["cliff"], (6.0, 6.0, 0.35), 0.9, 0.08, 5.0)
    MATS["grass"] = vc_mat("DIO_grass", rough=0.95)
    add_bump(MATS["grass"], (9.0, 9.0, 9.0), 0.35, 0.02, 6.0)
    MATS["foil"] = vc_mat("DIO_foil", rough=0.18, metal=0.85, spec=0.7, emit=(0.18, 0.42, 0.75))
    add_crinkle(MATS["foil"])
    MATS["glow"] = vc_mat("DIO_glow", emit=(1.0, 0.75, 0.4))


# ---------------------------------------------------------------- mesh helpers
class MeshBuilder:
    """Collects quads/tris with per-corner colours, then makes one object."""

    def __init__(s):
        s.verts, s.faces, s.cols = [], [], []

    def v(s, p):
        s.verts.append(tuple(p))
        return len(s.verts) - 1

    def f(s, idx, col):
        s.faces.append(tuple(idx))
        s.cols.append(col if isinstance(col, list) else [col] * len(idx))

    def obj(s, name, mat, collection, smooth=False):
        me = bpy.data.meshes.new(name)
        me.from_pydata(s.verts, [], s.faces)
        me.update()
        ca = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        k = 0
        for poly, cs in zip(me.polygons, s.cols):
            for li, c in zip(poly.loop_indices, cs):
                ca.data[li].color = (*c[:3], 1.0)
            k += 1
        me.materials.append(mat)
        for p in me.polygons:
            p.use_smooth = smooth
        o = bpy.data.objects.new(name, me)
        collection.objects.link(o)
        return o


def shade(c, k):
    return tuple(max(0.0, min(1.0, x * k)) for x in c)


def lerpc(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


# ---------------------------------------------------------------- outlines
def blob_outline(cx, cy, r, seed, n=None, rough=0.22, sx=1.0, sy=1.0):
    n = n or max(28, int(r * 18))
    pts = []
    for i in range(n):
        a = math.tau * i / n
        d = Vector((math.cos(a) * 1.7 + seed * 3.1, math.sin(a) * 1.7 + seed * 1.7, seed * 0.37))
        k = 1.0 + rough * noise.noise(d) + rough * 0.5 * noise.noise(d * 2.7)
        pts.append(Vector((cx + math.cos(a) * r * sx * k, cy + math.sin(a) * r * sy * k)))
    return pts


def board_outline():
    """The playable plateau: a rounded rectangle round the 16x11 board pushed out by noise, so
    every cell is on top and the edge never reads as a box."""
    hx, hy = COLS / 2 + 1.0, ROWS / 2 + 1.0
    pts = []
    n = 260
    for i in range(n):
        a = math.tau * i / n
        c, s = math.cos(a), math.sin(a)
        e = 2.0 / 10.0
        x = hx * math.copysign(abs(c) ** e, c)
        y = hy * math.copysign(abs(s) ** e, s)
        d = Vector((x * 0.21, y * 0.21, 4.2))
        push = 0.6 + 1.9 * (0.5 + 0.5 * noise.noise(d)) + 0.45 * noise.noise(d * 3.1)
        nrm = Vector((x / hx ** 2, y / hy ** 2)).normalized()
        pts.append(Vector((x, y)) + nrm * push)
    return pts


def inside(pt, poly):
    x, y = pt.x, pt.y
    ins = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi, xj, yj = poly[i].x, poly[i].y, poly[j].x, poly[j].y
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
            ins = not ins
        j = i
    return ins


# ---------------------------------------------------------------- plateau
KRAFT = srgb("#b9773c")
KRAFT_DARK = srgb("#5a3418")
GRASS = srgb("#6f8f3a")
GRASS_DRY = srgb("#a39a52")
GRASS_DARK = srgb("#4a6a2c")


def plateau(mb_top, mb_wall, outline, top_z, bot_z, seed, grass=True):
    """An extruded outline: a grass-paper top (a fan from the centroid with coloured noise) and a
    corrugated cardboard cliff (vertical flutes pushed out along the outline normal), darker
    towards the canyon floor (the crease AO we bake into the colours)."""
    n = len(outline)
    # resample the outline every ~0.09 m so the flutes are fine
    pts = []
    for i in range(n):
        a, b = outline[i], outline[(i + 1) % n]
        seg = (b - a).length
        k = max(1, int(seg / 0.09))
        for j in range(k):
            pts.append(a.lerp(b, j / k))
    m = len(pts)
    cen = sum(pts, Vector((0, 0))) / m
    # wall
    rows = [top_z, top_z - 0.12, top_z - 0.35 * (top_z - bot_z), bot_z]
    ring = []
    per = 0.0
    for i in range(m):
        a, b = pts[i - 1], pts[(i + 1) % m]
        tang = (b - a).normalized()
        nrm = Vector((tang.y, -tang.x))
        if i > 0:
            per += (pts[i] - pts[i - 1]).length
        flute = 0.07 * abs(math.sin(per * math.tau / 0.3))
        col_ring = []
        for zi, z in enumerate(rows):
            jag = 0.04 * noise.noise(Vector((per * 0.8, z * 0.5, seed)))
            off = flute + (jag if 0 < zi < 3 else 0.0) - (0.04 if zi == 0 else 0.0)
            p = pts[i] + nrm * off
            col_ring.append(mb_wall.v((p.x, p.y, z)))
        ring.append((col_ring, flute))
    depth = max(0.01, top_z - bot_z)
    for i in range(m):
        ca, fa = ring[i]
        cb, fb = ring[(i + 1) % m]
        for zi in range(3):
            def col(z, f):
                t = (top_z - z) / depth
                base = lerpc(KRAFT, KRAFT_DARK, min(1.0, t * 0.9 + 0.05))
                band = 0.93 if int((top_z - z) / 0.55) % 2 else 1.0
                return shade(base, (0.66 + 6.0 * f) * band)
            za, zb = rows[zi], rows[zi + 1]
            cs = [col(za, fa), col(za, fb), col(zb, fb), col(zb, fa)]
            if zi == 0:
                cs = [shade(KRAFT, 1.05)] * 2 + cs[2:]
            mb_wall.f([ca[zi], cb[zi], cb[zi + 1], ca[zi + 1]], cs)
    # top
    if grass:
        c_i = mb_top.v((cen.x, cen.y, top_z))
        idx = []
        for i in range(m):
            p = pts[i]
            idx.append(mb_top.v((p.x, p.y, top_z)))

        def gcol(p, edge):
            t = 0.5 + 0.5 * noise.noise(Vector((p.x * 0.18, p.y * 0.18, seed + 2.0)))
            g = lerpc(GRASS_DARK, GRASS, t)
            g = lerpc(g, GRASS_DRY, max(0.0, noise.noise(Vector((p.x * 0.5, p.y * 0.5, seed))) * 0.8))
            return shade(g, 0.92 if edge else 1.0)
        cc = gcol(cen, False)
        rings = []
        for k in (0.33, 0.66):
            ring_k = []
            for i in range(m):
                q = cen.lerp(pts[i], k)
                ring_k.append((mb_top.v((q.x, q.y, top_z)), gcol(q, False)))
            rings.append(ring_k)
        outer = [(idx[i], gcol(pts[i], True)) for i in range(m)]
        layers = rings + [outer]
        for i in range(m):
            j = (i + 1) % m
            a0, ca0 = layers[0][i]
            a1, ca1 = layers[0][j]
            mb_top.f([c_i, a0, a1], [cc, ca0, ca1])
            for L in range(len(layers) - 1):
                p0, c0 = layers[L][i]
                p1, c1 = layers[L][j]
                q0, d0 = layers[L + 1][i]
                q1, d1 = layers[L + 1][j]
                mb_top.f([p0, q0, q1, p1], [c0, d0, d1, c1])
    return pts


def grid_top(mb, outline, top_z, step=0.5):
    """A finer top for the board plateau so its colour can vary across the cells."""
    xs = [p.x for p in outline]
    ys = [p.y for p in outline]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    nx, ny = int((x1 - x0) / step) + 1, int((y1 - y0) / step) + 1
    ids = {}
    for iy in range(ny + 1):
        for ix in range(nx + 1):
            ids[(ix, iy)] = None

    def col(p):
        t = 0.5 + 0.5 * noise.noise(Vector((p.x * 0.16, p.y * 0.16, 9.0)))
        g = lerpc(GRASS_DARK, GRASS, t)
        g = lerpc(g, GRASS_DRY, max(0.0, noise.noise(Vector((p.x * 0.45, p.y * 0.45, 3.0))) * 0.9))
        return g
    for iy in range(ny):
        for ix in range(nx):
            q = [Vector((x0 + (ix + dx) * step, y0 + (iy + dy) * step)) for dx, dy in ((0, 0), (1, 0), (1, 1), (0, 1))]
            c = (q[0] + q[2]) / 2
            if not inside(c, outline):
                continue
            vi = []
            for p in q:
                vi.append(mb.v((p.x, p.y, top_z)))
            mb.f(vi, [col(p) for p in q])


# ---------------------------------------------------------------- the path
PATH = srgb("#d9b98a")
PATH_DARK = srgb("#b89262")


def road(mb, pts, width=0.9, z=0.02):
    """The road as a strip of torn kraft paper: ragged edges from noise, lighter in the middle."""
    left, right = [], []
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        t = (b - a).normalized()
        n = Vector((-t.y, t.x))
        wl = width / 2 + 0.07 * noise.noise(Vector((p.x * 2.1, p.y * 2.1, 1.0)))
        wr = width / 2 + 0.07 * noise.noise(Vector((p.x * 2.1, p.y * 2.1, 5.0)))
        left.append(mb.v((p.x + n.x * wl, p.y + n.y * wl, z)))
        mid = mb.v((p.x, p.y, z + 0.004))
        right.append(mb.v((p.x - n.x * wr, p.y - n.y * wr, z)))
        left[-1] = (left[-1], mid)
    for i in range(len(pts) - 1):
        l0, m0 = left[i]
        l1, m1 = left[i + 1]
        r0, r1 = right[i], right[i + 1]
        mb.f([l0, l1, m1, m0], [PATH_DARK, PATH_DARK, PATH, PATH])
        mb.f([m0, m1, r1, r0], [PATH, PATH, PATH_DARK, PATH_DARK])


def route_pts(i):
    return [Vector((x, -z)) for x, z in B["routes_world"][i]]


def extend(pts, toward, length, step=0.25, wiggle=0.6, seed=0.0):
    """Carries a road on past the board's edge, so the foes come from somewhere."""
    out = []
    p = pts[0]
    d = toward.normalized()
    for k in range(1, int(length / step)):
        q = p + d * (k * step)
        side = Vector((-d.y, d.x)) * wiggle * noise.noise(Vector((k * step * 0.15, seed, 0.0)))
        out.append(q + side)
    out.reverse()
    return out + pts


# ---------------------------------------------------------------- props
def import_glb(path, collection):
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=path)
    new = [bpy.data.objects[k] for k in bpy.data.objects.keys() if k not in before]
    for o in new:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        collection.objects.link(o)
    roots = [o for o in new if o.parent is None]
    return roots, new


PROTOS = {}


def proto(key, path):
    """Imports a glb once into a hidden collection; returns that collection for instancing."""
    if key in PROTOS:
        return PROTOS[key]
    c = bpy.data.collections.get("P_" + key) or bpy.data.collections.new("P_" + key)
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    roots, new = import_glb(path, c)
    for o in new:
        o.animation_data_clear()
    PROTOS[key] = c
    return c


def proto_height(c):
    zs = []
    for o in c.all_objects:
        if o.type == "MESH":
            for v in o.bound_box:
                zs.append((o.matrix_world @ Vector(v)).z)
    return (min(zs), max(zs)) if zs else (0.0, 1.0)


FOE_HEIGHT = {"scrap_goblin": 0.8, "corrugated_orc": 1.2, "cardboard_golem": 2.0, "ink_shaman": 1.0, "razor_moth": 0.8}


def place_foe(key, at, facing, collection):
    """A foe as the game draws it: scaled to its height, feet on the ground, facing along the
    road (the models face glTF +Z, Blender -Y, at yaw 0)."""
    c = proto(key, MODELS + "/enemies/%s.glb" % key)
    z0, z1 = proto_height(c)
    k = FOE_HEIGHT[key] / max(1e-3, z1 - z0)
    e = place(key, MODELS + "/enemies/%s.glb" % key, at, math.atan2(facing.y, facing.x) + math.pi / 2, k, collection)
    e.location.z = at.z - z0 * k
    return e


def place(key, path, at, rot=0.0, scale=1.0, collection=None):
    c = proto(key, path)
    e = bpy.data.objects.new(key, None)
    e.instance_type = "COLLECTION"
    e.instance_collection = c
    e.location = at
    e.rotation_euler = (0, 0, rot)
    e.scale = (scale, scale, scale)
    (collection or coll("Props")).objects.link(e)
    return e


def glb_up_fix(c):
    """glTF imports with Y up already converted; nothing to do (kept for clarity)."""
    return c


def rock(mb, at, r, seed):
    """A low-poly folded-card rock: a jittered octahedron-ish lump with faceted shading."""
    rr = random.Random(seed)
    n_ring = 6
    pts = []
    top = mb.v(at + Vector((rr.uniform(-0.1, 0.1) * r, rr.uniform(-0.1, 0.1) * r, r * rr.uniform(0.8, 1.2))))
    ring = []
    a0 = rr.uniform(0, 6.28)
    for i in range(n_ring):
        a = a0 + math.tau * i / n_ring
        k = r * rr.uniform(0.75, 1.15)
        ring.append(mb.v(at + Vector((math.cos(a) * k, math.sin(a) * k * rr.uniform(0.7, 1.0), r * rr.uniform(0.25, 0.5)))))
    base = []
    for i in range(n_ring):
        a = a0 + math.tau * (i + 0.5) / n_ring
        k = r * rr.uniform(0.85, 1.2)
        base.append(mb.v(at + Vector((math.cos(a) * k, math.sin(a) * k, -0.05))))
    tone = srgb(rr.choice(["#9b8b78", "#a89a86", "#8c7b68", "#b0a08a"]))
    for i in range(n_ring):
        j = (i + 1) % n_ring
        mb.f([top, ring[i], ring[j]], shade(tone, 1.1 + 0.08 * ((i * 3) % 3)))
        mb.f([ring[i], base[i], ring[j]], shade(tone, 0.8 + 0.06 * (i % 3)))
        mb.f([ring[j], base[i], base[j]], shade(tone, 0.72))


def d20(mb, at, r, seed):
    """A paper twenty-sided die resting on a face: an icosahedron with slightly shaded faces."""
    t = (1 + 5 ** 0.5) / 2
    vs = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
          (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    fs = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
          (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10),
          (8, 6, 7), (9, 8, 1)]
    rot = Matrix.Rotation(seed * 2.3, 3, "Z") @ Matrix.Rotation(0.36, 3, "X")
    sc = r / math.sqrt(1 + t * t)
    ids = [mb.v(at + rot @ (Vector(v) * sc) + Vector((0, 0, r * 0.8))) for v in vs]
    base = srgb("#cdb79a")
    for k, f in enumerate(fs):
        c = shade(base, 0.86 + 0.18 * ((k * 7) % 5) / 4)
        mb.f([ids[i] for i in f], c)


# ---------------------------------------------------------------- foil river
def river(mb, pts, width, z):
    for i, p in enumerate(pts):
        pass
    L, R = [], []
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        t = (b - a).normalized()
        n = Vector((-t.y, t.x))
        w = width * (0.85 + 0.3 * noise.noise(Vector((p.x * 0.2, p.y * 0.2, 7.0))))
        L.append(mb.v((p.x + n.x * w / 2, p.y + n.y * w / 2, z)))
        R.append(mb.v((p.x - n.x * w / 2, p.y - n.y * w / 2, z)))
    for i in range(len(pts) - 1):
        def c(k):
            return lerpc(srgb("#7fc4f2"), srgb("#2f6fbf"), 0.5 + 0.5 * math.sin(k * 1.7))
        mb.f([L[i], L[i + 1], R[i + 1], R[i]], [c(i), c(i + 1), c(i + 2), c(i + 3)])


def spline(ctrl, step=0.4):
    out = []
    for i in range(len(ctrl) - 1):
        p0 = ctrl[max(0, i - 1)]
        p1, p2 = ctrl[i], ctrl[i + 1]
        p3 = ctrl[min(len(ctrl) - 1, i + 2)]
        seg = (p2 - p1).length
        k = max(2, int(seg / step))
        for j in range(k):
            t = j / k
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(ctrl[-1])
    return out


# ---------------------------------------------------------------- bridges
def bridge(mb_deck, mb_rope, a, b, z, width=0.9):
    d = b - a
    L = d.length
    t = d.normalized()
    n = Vector((-t.y, t.x))
    planks = int(L / 0.22)
    sag = 0.25
    for k in range(planks):
        s0 = k / planks
        s1 = (k + 0.75) / planks
        zz = z - sag * 4 * s0 * (1 - s0)
        p0, p1 = a + d * s0, a + d * s1
        c = shade(srgb("#b88a55"), 0.85 + 0.2 * ((k * 5) % 3) / 2)
        q = [p0 + n * width / 2, p1 + n * width / 2, p1 - n * width / 2, p0 - n * width / 2]
        ids = [mb_deck.v((p.x, p.y, zz)) for p in q]
        mb_deck.f(ids, c)
    for side in (1, -1):
        for k in range(planks):
            s0, s1 = k / planks, (k + 1) / planks
            z0 = z + 0.45 - sag * 4 * s0 * (1 - s0)
            z1 = z + 0.45 - sag * 4 * s1 * (1 - s1)
            p0 = a + d * s0 + n * side * width / 2
            p1 = a + d * s1 + n * side * width / 2
            r = 0.02
            ids = [mb_rope.v((p0.x, p0.y, z0 - r)), mb_rope.v((p1.x, p1.y, z1 - r)),
                   mb_rope.v((p1.x, p1.y, z1 + r)), mb_rope.v((p0.x, p0.y, z0 + r))]
            mb_rope.f(ids, srgb("#8a6a45"))


def bridge_along(mb_deck, mb_rope, pts, z, width=1.0, sag=0.25):
    """A rope bridge that follows the road's curve: card planks across it, sagging in the middle,
    and a rope rail on each side."""
    L = [0.0]
    for a, b in zip(pts, pts[1:]):
        L.append(L[-1] + (b - a).length)
    total = max(1e-6, L[-1])

    def frame(k):
        a = pts[max(0, k - 1)]
        b = pts[min(len(pts) - 1, k + 1)]
        t = (b - a).normalized()
        return Vector((-t.y, t.x))

    for k in range(len(pts) - 1):
        s0, s1 = L[k] / total, L[k + 1] / total
        z0 = z - sag * 4 * s0 * (1 - s0)
        n0, n1 = frame(k), frame(k + 1)
        p0, p1 = pts[k], pts[k].lerp(pts[k + 1], 0.72)
        c = shade(srgb("#b88a55"), 0.85 + 0.2 * ((k * 5) % 3) / 2)
        q = [p0 + n0 * width / 2, p1 + n1 * width / 2, p1 - n1 * width / 2, p0 - n0 * width / 2]
        mb_deck.f([mb_deck.v((p.x, p.y, z0)) for p in q], c)
        for side in (1, -1):
            z1 = z - sag * 4 * s1 * (1 - s1)
            a = pts[k] + n0 * side * width / 2
            b = pts[k + 1] + n1 * side * width / 2
            r = 0.02
            ids = [mb_rope.v((a.x, a.y, z0 + 0.45 - r)), mb_rope.v((b.x, b.y, z1 + 0.45 - r)),
                   mb_rope.v((b.x, b.y, z1 + 0.45 + r)), mb_rope.v((a.x, a.y, z0 + 0.45 + r))]
            mb_rope.f(ids, srgb("#8a6a45"))


# ---------------------------------------------------------------- build
def build(seed=11):
    global rng
    rng = random.Random(seed)
    sc = fresh_scene()
    make_materials()
    C_T = coll("Terrain")
    C_P = coll("Props")
    top_mb, wall_mb, road_mb, deck_mb, rope_mb, d20_mb, foil_mb = (MeshBuilder() for _ in range(7))

    # the playable plateau
    bo = board_outline()
    plateau(top_mb, wall_mb, bo, 0.0, CANYON_Z, 1.0)

    # socket mesas
    for col, row, lvl in B["sockets"]:
        cen = cell_c(col, row) + Vector((0.5, -0.5, 0))
        h = LEVEL_H[lvl]
        if h > 0:
            o = blob_outline(cen.x, cen.y, 1.18, col * 3.1 + row, rough=0.08, n=48)
            plateau(top_mb, wall_mb, o, h, 0.0, col + row * 0.3)

    # roads: the two routes, carried on past the board edge to where they come from
    r0 = route_pts(0)
    r1 = route_pts(1)
    r0x = extend(r0, Vector((-1, 0.15)), 9.0, seed=1.0)
    r1x = extend(r1, Vector((0.1, 1)), 10.0, seed=2.0)

    # surround: plateaus scattered round the board, none on it or on the river
    river_ctrl = [Vector(p) for p in [(13.5, -30), (12.0, -14), (11.2, -6), (11.4, 2), (13.0, 9), (10.5, 18), (14.0, 30), (11.0, 48), (16.0, 70)]]
    riv = spline(river_ctrl)

    def near_river(p, w):
        return min((p - q).length for q in riv[::3]) < w

    placed = []
    attempts = 0
    road_far = [p for p in r0x[:30]] + [p for p in r1x[:34]]
    while len(placed) < 95 and attempts < 4000:
        attempts += 1
        ang = rng.uniform(0, math.tau)
        rad = rng.uniform(11.0, 68.0)
        c = Vector((math.cos(ang) * rad * 1.15, math.sin(ang) * rad))
        if c.y < -16 and rng.random() < 0.7:
            continue
        r = rng.uniform(1.6, 3.2) + rad * 0.045
        if inside(c, bo) or min((c - p).length for p in bo[::6]) < r + 1.4:
            continue
        if near_river(c, r + 1.6):
            continue
        if any((c - q).length < r + rq + 0.9 for q, rq in placed):
            continue
        if min((c - p).length for p in road_far) < r + 0.8:
            continue
        top = rng.choice([-1.0, -0.4, 0.0, 0.0, 0.6, 1.2, 1.8, 2.6])
        if rad > 24:
            top += (rad - 24) * rng.uniform(0.1, 0.22)
        if c.y < -8:
            top = min(top, -0.6)
        o = blob_outline(c.x, c.y, r, len(placed) * 1.37, rough=0.24)
        plateau(top_mb, wall_mb, o, top, CANYON_Z - 0.3, len(placed) * 0.71)
        placed.append((c, r))
        # dressing on it
        if rng.random() < 0.18 and r > 2.2:
            d20(d20_mb, Vector((c.x, c.y, top)), rng.uniform(1.0, 1.6), len(placed))
        else:
            for k in range(rng.randint(5, 14)):
                a2 = rng.uniform(0, math.tau)
                rr = rng.uniform(0, r * 0.7)
                p = Vector((c.x + math.cos(a2) * rr, c.y + math.sin(a2) * rr, top))
                key = rng.choice(["decor_tree_pine", "decor_tree_pine", "decor_tree_round"])
                place(key, MODELS + "/terrain/%s.glb" % key, p, rng.uniform(0, 6.28), rng.uniform(1.4, 2.4), C_P)

    # each road leaves the board plateau over a rope bridge to land that carries it away
    bridges = []
    for pts, s in ((r0x, 3.0), (r1x, 4.0)):
        out = [p for p in pts if not inside(p, bo)]
        if not out:
            continue
        edge = out[-1]
        far = [p for p in out if (p - edge).length > 3.2]
        if far:
            land_from = far[-1]
            bridges.append((edge, land_from))
        on_board = [p for p in pts if inside(p, bo)]
        road(road_mb, far, z=0.02 + (s - 3.0) * 0.004)
        road(road_mb, on_board, z=0.02 + (s - 3.0) * 0.004)
        for k, p in enumerate(far[::6]):
            o = blob_outline(p.x, p.y, 1.75, s + k * 0.3, rough=0.12)
            plateau(top_mb, wall_mb, o, -0.0015 * (k + 1), CANYON_Z - 0.3, s + k)

    # far paper mountains: layered cut-card ridges standing at the horizon
    mt = MeshBuilder()
    for layer, (dist, hmin, hmax, colr) in enumerate(((95, 10, 22, "#9c8a72"), (125, 16, 30, "#a99d8d"), (160, 22, 40, "#b8b3ab"))):
        n = 70
        prev = None
        for i in range(n + 1):
            a = math.radians(10 + 200 * i / n)
            h = hmin + (hmax - hmin) * (0.5 + 0.5 * noise.noise(Vector((i * 0.21, layer * 3.0, 0.5))))
            p = Vector((math.cos(a) * dist * 1.25, math.sin(a) * dist))
            lo = mt.v((p.x, p.y, CANYON_Z))
            hi = mt.v((p.x, p.y, h))
            if prev:
                mt.f([prev[0], lo, hi, prev[1]], [srgb(colr)] * 2 + [shade(srgb(colr), 1.08)] * 2)
            prev = (lo, hi)
    mt.obj("PaperMountains", MATS["paper"], C_T)

    # canyon floor and the foil river
    fl = MeshBuilder()
    R = 90
    ids = [fl.v((x * R, y * R, CANYON_Z - 0.3)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    fl.f(ids, srgb("#3e2b1c"))
    river(foil_mb, riv, 3.2, CANYON_Z - 0.25)

    for a_, b_ in bridges:
        d = (b_ - a_).normalized()
        bridge(deck_mb, rope_mb, a_ - d * 0.4, b_ + d * 0.4, 0.03)
    # trees and dressing on the board plateau, off the road and the sockets
    road_all = r0x + r1x
    sock_c = [cell_c(c, r) + Vector((0.5, -0.5, 0)) for c, r, _ in B["sockets"]]
    hs = B["heartstone"]
    hs_c = cell_c(hs[0], hs[1]) + Vector((0.5, -0.5, 0))
    for k in range(70):
        p = Vector((rng.uniform(-COLS / 2 - 1.2, COLS / 2 + 1.2), rng.uniform(-ROWS / 2 - 1.2, ROWS / 2 + 1.2), 0.0))
        if not inside(p, bo) or min((p - Vector((q.x, q.y, 0))).length for q in road_all[::2]) < 0.9:
            continue
        if min((p - s).length for s in sock_c) < 1.5 or (p - hs_c).length < 1.6:
            continue
        key = rng.choice(["decor_tree_pine", "decor_tree_pine", "decor_tree_round", "decor_shrub", "decor_grass", "decor_flowers"])
        place(key, MODELS + "/terrain/%s.glb" % key, p, rng.uniform(0, 6.28), rng.uniform(0.9, 1.4), C_P)

    top_mb.obj("Tops", MATS["grass"], C_T)
    wall_mb.obj("Cliffs", MATS["cliff"], C_T)
    road_mb.obj("Road", MATS["paper"], C_T)
    deck_mb.obj("BridgeDecks", MATS["paper"], C_T)
    rope_mb.obj("BridgeRopes", MATS["paper"], C_T)
    d20_mb.obj("Dice", MATS["paper"], C_T)
    foil_mb.obj("FoilRiver", MATS["foil"], C_T)
    fl.obj("CanyonFloor", MATS["paper"], C_T)
    return {"plateaus": len(placed), "verts": len(top_mb.verts) + len(wall_mb.verts)}


# ---------------------------------------------------------------- towers, foes, heartstone
TOWER_FILES = {"spoolGuard": "spool_guard", "thimbleMortar": "thimble_mortar", "prismSpire": "prism_spire",
               "guardTent": "guard_tent", "messTent": "kitchen_mess_tent"}


def stage_units():
    C = coll("Units")
    for o in list(C.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    order = ["spoolGuard", "thimbleMortar", "prismSpire", "guardTent", "spoolGuard", "messTent", "prismSpire", "thimbleMortar"]
    for k, (col, row, lvl) in enumerate(B["sockets"][:12]):
        cen = cell_c(col, row) + Vector((0.5, -0.5, LEVEL_H[lvl]))
        t = order[k % len(order)]
        place(t, MODELS + "/towers/%s.glb" % TOWER_FILES[t], cen, math.radians(rng.uniform(-30, 30)), 1.0, C)
    hs = B["heartstone"]
    place("heartstone", MODELS + "/towers/heartstone.glb", cell_c(hs[0], hs[1]) + Vector((0.5, -0.5, 0)), 0.0, 1.0, C)
    pts = route_pts(0)
    foes = ["scrap_goblin"] * 10 + ["corrugated_orc"] * 4 + ["cardboard_golem", "ink_shaman", "ink_shaman"]
    rng2 = random.Random(5)
    for k, f in enumerate(foes):
        i = 14 + k * 5 + rng2.randint(0, 2)
        if i >= len(pts) - 1:
            break
        p, q = pts[i], pts[i + 1]
        d = q - p
        yaw = math.atan2(d.y, d.x) - math.pi / 2
        side = Vector((-d.y, d.x)).normalized() * rng2.uniform(-0.18, 0.18)
        place_foe(f, Vector((p.x + side.x, p.y + side.y, 0.0)), d, C)
    pts1 = route_pts(1)
    for k in range(4):
        i = 6 + k * 4
        p, q = pts1[i], pts1[i + 1]
        d = q - p
        place_foe("razor_moth" if k == 2 else "scrap_goblin", Vector((p.x, p.y, 0.7 if k == 2 else 0.0)), d, C)


# ---------------------------------------------------------------- light, camera, render
def light_and_camera(pitch=36.0, yaw=30.0, fov=36.0, dist=36.0, target=(-1.5, 3.0, 0.0), width=1280, height=720,
                     sun_tilt=60.0, sun_turn=-140.0, sky=0.55):
    sc = bpy.context.scene
    for o in list(sc.objects):
        if o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o, do_unlink=True)
    sun_d = bpy.data.lights.new("Sun", "SUN")
    sun_d.energy = 4.6
    sun_d.color = srgb("#ffd9a8")
    sun_d.angle = math.radians(3.0)
    sun = bpy.data.objects.new("Sun", sun_d)
    sun.rotation_euler = (math.radians(sun_tilt), 0.0, math.radians(sun_turn))
    sc.collection.objects.link(sun)
    w = sc.world or bpy.data.worlds.new("DioWorld")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (*srgb("#b9cbe0"), 1.0)
    bg.inputs[1].default_value = sky
    cam_d = bpy.data.cameras.new("GameCam")
    cam_d.sensor_fit = "VERTICAL"
    cam_d.angle_y = math.radians(fov)
    cam_d.clip_start = 0.5
    cam_d.clip_end = 400.0
    cam = bpy.data.objects.new("GameCam", cam_d)
    sc.collection.objects.link(cam)
    if dist is None:
        dist = 13.0 / math.tan(math.radians(fov / 2)) * 0.62
    tgt = Vector(target)
    p = math.radians(pitch)
    y = math.radians(yaw)
    off = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p))) * dist
    cam.location = tgt + off
    look = (tgt - cam.location).normalized()
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x = width
    sc.render.resolution_y = height
    sc.render.resolution_percentage = 100
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    ee = sc.eevee
    for k, v in (("use_raytracing", False), ("use_shadows", True), ("shadow_ray_count", 2), ("shadow_step_count", 6), ("taa_render_samples", 32)):
        if hasattr(ee, k):
            setattr(ee, k, v)
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast" if "AgX - Medium High Contrast" in [i.identifier for i in sc.view_settings.bl_rna.properties["look"].enum_items] else "None"
    vl = sc.view_layers[0]
    vl.use_pass_z = True
    vl.use_pass_mist = True
    w.mist_settings.start = 12.0
    w.mist_settings.depth = 140.0
    w.mist_settings.falloff = "LINEAR"
    return {"cam": tuple(cam.location), "dist": dist}


def render(name):
    sc = bpy.context.scene
    ims = sc.render.image_settings
    if hasattr(ims, "media_type"):
        ims.media_type = "MULTI_LAYER_IMAGE"
        ims.file_format = "OPEN_EXR_MULTILAYER"
    else:
        ims.file_format = "OPEN_EXR_MULTILAYER"
    ims.color_depth = "32"
    sc.render.filepath = HERE + "/renders/" + name + ".exr"
    bpy.ops.render.render(write_still=True)
    if hasattr(ims, "media_type"):
        ims.media_type = "IMAGE"
    ims.file_format = "PNG"
    ims.color_depth = "8"
    img = bpy.data.images["Render Result"]
    img.save_render(HERE + "/renders/" + name + ".png")
    return sc.render.filepath


# ---------------------------------------------------------------- the world: a terraced height field
LEVELS = [-1.7, 0.0, 1.7, 3.6, 5.8, 8.4, 11.4, 15.0]


def _fbm(x, y, z, oct=4):
    v, a, f = 0.0, 0.5, 1.0
    for _ in range(oct):
        v += a * noise.noise(Vector((x * f, y * f, z)))
        a *= 0.5
        f *= 2.03
    return v


def world_field(bo, corridors, river_pts, res=0.5, box=(-80.0, 80.0, -38.0, 118.0)):
    """Height in metres at every node of a grid round the board: smooth noise that climbs with
    distance, cut by winding side canyons and the river canyon; the board and a moat round it are
    left to the board plateau; the roads carry on on land at the board's level."""
    import numpy as np
    x0, x1, y0, y1 = box
    xs = np.arange(x0, x1 + 1e-6, res)
    ys = np.arange(y0, y1 + 1e-6, res)
    H = np.zeros((len(ys), len(xs)), np.float32)
    for i, y in enumerate(ys):
        for j, x in enumerate(xs):
            n1 = _fbm(x * 0.045, y * 0.045, 1.3)
            n2 = _fbm(x * 0.11, y * 0.11, 7.7, 3)
            ridge = abs(noise.noise(Vector((x * 0.035, y * 0.035, 3.3))))
            d = math.hypot(x / 1.2, y + 2.0)
            h = 0.6 + 4.2 * n1 + 0.6 * n2 + 0.16 * max(0.0, d - 14.0)
            if ridge < 0.075 and d > 15:
                h -= 12.0
            if y < -6.0:
                # keep the ground in front of the board low, so it never covers the board
                h = min(h, -0.2 - 0.12 * (-6.0 - y))
            H[i, j] = h
    X, Y = np.meshgrid(xs, ys)
    # river canyon
    rp = np.array([(p.x, p.y) for p in river_pts], np.float32)
    for i in range(len(ys)):
        dx = X[i][:, None] - rp[None, :, 0]
        dy = Y[i][:, None] - rp[None, :, 1]
        dr = np.sqrt((dx * dx + dy * dy).min(1))
        H[i] = np.where(dr < 3.4 + 1.2 * np.sin(X[i] * 0.21 + Y[i] * 0.13), -9.0, H[i])
    # the board and its moat stay canyon (the board plateau is built on its own)
    bp = np.array([(p.x, p.y) for p in bo], np.float32)
    bx0, bx1 = bp[:, 0].min() - 4.5, bp[:, 0].max() + 4.5
    by0, by1 = bp[:, 1].min() - 4.5, bp[:, 1].max() + 4.5
    sel = (X > bx0) & (X < bx1) & (Y > by0) & (Y < by1)
    idx = np.argwhere(sel)
    pts = np.stack([X[sel], Y[sel]], 1)
    dmin = np.full(len(pts), 1e9, np.float32)
    for k in range(len(bp)):
        a, b = bp[k], bp[(k + 1) % len(bp)]
        ab = b - a
        t = np.clip(((pts - a) @ ab) / (ab @ ab + 1e-9), 0, 1)
        q = a + t[:, None] * ab
        dmin = np.minimum(dmin, np.sqrt(((pts - q) ** 2).sum(1)))
    moat = 2.2 + 1.0 * np.sin(pts[:, 0] * 0.7) * np.cos(pts[:, 1] * 0.5)
    ins = np.array([inside(Vector((float(p[0]), float(p[1]))), bo) for p in pts])
    kill = ins | (dmin < moat)
    for (i, j), k in zip(idx, kill):
        if k:
            H[i, j] = -9.0
    # the roads beyond the board run on land at the board's level
    for cpts, start in corridors:
        cp = np.array([(p.x, p.y) for p in cpts], np.float32)
        for i in range(len(ys)):
            dx = X[i][:, None] - cp[None, :, 0]
            dy = Y[i][:, None] - cp[None, :, 1]
            dr = np.sqrt((dx * dx + dy * dy).min(1))
            H[i] = np.where(dr < 1.9, 0.35, np.where(dr < 3.0, np.maximum(H[i], 0.35), H[i]))
    return xs, ys, H


def terraces(top_mb, wall_mb, xs, ys, H):
    """Marching squares on each level of the height field: a top at the level's height over
    everything at or above it (cells wholly under the next level are skipped, it covers them),
    and a corrugated cardboard wall down to the level below along its contour."""
    import numpy as np
    ny, nx = H.shape
    res = float(xs[1] - xs[0])
    for L, h in enumerate(LEVELS):
        S = H - h
        Sn = H - LEVELS[L + 1] if L + 1 < len(LEVELS) else np.full_like(H, -1.0)
        below = LEVELS[L - 1] if L > 0 else CANYON_Z - 0.3
        inside_any = (S[:-1, :-1] >= 0) | (S[:-1, 1:] >= 0) | (S[1:, 1:] >= 0) | (S[1:, :-1] >= 0)
        cells = np.argwhere(inside_any)
        for i, j in cells:
            c = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]
            v = [float(S[a, b]) for a, b in c]
            pos = [Vector((float(xs[b]), float(ys[a]))) for a, b in c]
            covered = all(Sn[a, b] >= 0 for a, b in c)
            poly, cross = [], []
            for k in range(4):
                a, b = k, (k + 1) % 4
                if v[a] >= 0:
                    poly.append(pos[a])
                if (v[a] >= 0) != (v[b] >= 0):
                    t = v[a] / (v[a] - v[b])
                    q = pos[a].lerp(pos[b], t)
                    poly.append(q)
                    cross.append(q)
            if not covered and len(poly) >= 3:
                ids = [top_mb.v((p.x, p.y, h)) for p in poly]
                top_mb.f(ids, [terrace_top_colour(p, h) for p in poly])
            if len(cross) >= 2:
                segs = [(cross[0], cross[1])] if len(cross) == 2 else [(cross[0], cross[1]), (cross[2], cross[3])]
                gx = (v[1] + v[2] - v[0] - v[3]) / 2
                gy = (v[2] + v[3] - v[0] - v[1]) / 2
                out = -Vector((gx, gy))
                for A, Bp in segs:
                    wall_strip(wall_mb, A, Bp, out, h, below)


def terrace_top_colour(p, h):
    t = 0.5 + 0.5 * noise.noise(Vector((p.x * 0.12, p.y * 0.12, h)))
    g = lerpc(GRASS_DARK, GRASS, t)
    g = lerpc(g, GRASS_DRY, max(0.0, noise.noise(Vector((p.x * 0.33, p.y * 0.33, 4.0)))) * 0.9)
    dirt = noise.noise(Vector((p.x * 0.21, p.y * 0.21, 17.0))) + 0.4 * noise.noise(Vector((p.x * 0.7, p.y * 0.7, 3.0)))
    if dirt > 0.28:
        g = lerpc(g, srgb("#9a7444"), min(1.0, (dirt - 0.28) * 4.0))
    if h < -0.5:
        g = lerpc(g, srgb("#8f8a5a"), 0.35)
    return g


def wall_strip(mb, A, Bp, out, top, bot, pieces=3):
    d = Bp - A
    if (Vector((-d.y, d.x)).dot(out)) < 0:
        A, Bp = Bp, A
        d = Bp - A
    n = Vector((-d.y, d.x)).normalized() if d.length > 1e-6 else Vector((0, 0))
    depth = max(0.05, top - bot)
    rows = [top, top - 0.14, top - 0.45 * depth, bot]
    prev = None
    for k in range(pieces + 1):
        p = A.lerp(Bp, k / pieces)
        r = noise.noise(Vector((p.x * 2.6, p.y * 2.6, 0.5)))
        ridge = 0.06 * (0.5 + 0.5 * r)
        col_ids = []
        cols = []
        for zi, z in enumerate(rows):
            off = ridge if zi > 0 else ridge * 0.4
            q = p + n * off
            col_ids.append(mb.v((q.x, q.y, z)))
            t = (top - z) / depth
            base = lerpc(KRAFT, KRAFT_DARK, min(1.0, 0.1 + 0.8 * t + 0.08 * (bot < CANYON_Z + 0.5)))
            if zi == 0:
                cols.append(srgb("#7b8a35"))
            elif zi == 1:
                cols.append(srgb("#7a4f2a"))
            else:
                cols.append(shade(base, 0.7 + 0.55 * (0.5 + 0.5 * r)))
        if prev is not None:
            pi, pc = prev
            for zi in range(3):
                mb.f([pi[zi], col_ids[zi], col_ids[zi + 1], pi[zi + 1]], [pc[zi], cols[zi], cols[zi + 1], pc[zi + 1]])
        prev = (col_ids, cols)


def level_at(xs, ys, H, p):
    import numpy as np
    j = int(round((p.x - xs[0]) / (xs[1] - xs[0])))
    i = int(round((p.y - ys[0]) / (ys[1] - ys[0])))
    if not (0 < i < H.shape[0] - 1 and 0 < j < H.shape[1] - 1):
        return None
    win = H[i - 1:i + 2, j - 1:j + 2]
    lv = [L for L, h in enumerate(LEVELS) if win.min() >= h]
    lv_c = [L for L, h in enumerate(LEVELS) if H[i, j] >= h]
    if not lv or not lv_c or lv[-1] != lv_c[-1]:
        return None
    return LEVELS[lv[-1]]


def build_world(seed=11):
    """The board plateau, its socket mesas, roads and bridges, then the terraced world round it."""
    global rng
    rng = random.Random(seed)
    sc = fresh_scene()
    make_materials()
    C_T = coll("Terrain")
    C_P = coll("Props")
    top_mb, wall_mb, road_mb, deck_mb, rope_mb, d20_mb, foil_mb = (MeshBuilder() for _ in range(7))
    bo = board_outline()
    plateau(top_mb, wall_mb, bo, 0.0, CANYON_Z - 0.3, 1.0)
    for col, row, lvl in B["sockets"]:
        cen = cell_c(col, row) + Vector((0.5, -0.5, 0))
        h = LEVEL_H[lvl]
        if h > 0:
            o = blob_outline(cen.x, cen.y, 1.18, col * 3.1 + row, rough=0.08, n=48)
            plateau(top_mb, wall_mb, o, h, 0.0, col + row * 0.3)
    r0, r1 = route_pts(0), route_pts(1)
    r0x = extend(r0, Vector((-1, 0.15)), 30.0, seed=1.0)
    r1x = extend(r1, Vector((0.1, 1)), 34.0, seed=2.0)
    bridges, corridors = [], []
    for pts, s in ((r0x, 3.0), (r1x, 4.0)):
        out = [p for p in pts if not inside(p, bo)]
        edge = out[-1]
        far = [p for p in out if (p - edge).length > 3.4]
        bridges.append((edge, far[-1]))
        corridors.append((far, far[-1]))
        road(road_mb, far, z=0.37 + (s - 3.0) * 0.004)
        road(road_mb, [p for p in pts if inside(p, bo)], z=0.02 + (s - 3.0) * 0.004)
    for a_, b_ in bridges:
        d = (b_ - a_).normalized()
        bridge(deck_mb, rope_mb, a_ - d * 0.4, b_ + d * 0.5, 0.05)
    river_ctrl = [Vector(p) for p in [(15.5, -40), (13.0, -16), (12.6, -6), (13.0, 2), (14.5, 9), (12.0, 18), (15.0, 30), (11.0, 48), (17.0, 70), (12.0, 95), (18.0, 125)]]
    riv = spline(river_ctrl)
    xs, ys, H = world_field(bo, corridors, riv)
    terraces(top_mb, wall_mb, xs, ys, H)
    # canyon floor, foil river, far paper mountains
    fl = MeshBuilder()
    R = 160
    ids = [fl.v((x * R, y * R + 40, CANYON_Z - 0.3)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    fl.f(ids, srgb("#3e2b1c"))
    river(foil_mb, riv, 3.4, CANYON_Z - 0.25)
    mt = MeshBuilder()
    for layer, (dist, hmin, hmax, colr) in enumerate(((128, 18, 30, "#9c8a72"), (150, 24, 40, "#a99d8d"), (178, 30, 52, "#b8b3ab"))):
        n = 80
        prev = None
        for i in range(n + 1):
            a = math.radians(10 + 200 * i / n)
            hh = hmin + (hmax - hmin) * (0.5 + 0.5 * noise.noise(Vector((i * 0.21, layer * 3.0, 0.5))))
            p = Vector((math.cos(a) * dist * 1.25, math.sin(a) * dist))
            lo = mt.v((p.x, p.y, CANYON_Z))
            hi = mt.v((p.x, p.y, hh))
            if prev:
                mt.f([prev[0], lo, hi, prev[1]], [srgb(colr)] * 2 + [shade(srgb(colr), 1.08)] * 2)
            prev = (lo, hi)
    # forests, dice and camps on the terraces
    trees = 0
    for k in range(5200):
        p = Vector((rng.uniform(xs[0], xs[-1]), rng.uniform(ys[0], ys[-1])))
        if p.y < -14 and rng.random() < 0.6:
            continue
        forest = noise.noise(Vector((p.x * 0.07, p.y * 0.07, 11.0)))
        if forest < -0.05:
            continue
        h = level_at(xs, ys, H, p)
        if h is None:
            continue
        if h < -1.0:
            if rng.random() < 0.35:
                key = rng.choice(["decor_shrub", "decor_tree_round", "decor_scrap"])
                place(key, MODELS + "/terrain/%s.glb" % key, Vector((p.x, p.y, h)), rng.uniform(0, 6.28), rng.uniform(1.2, 2.0), C_P)
            continue
        if min((p - q).length for q in corridors[0][0][::4] + corridors[1][0][::4]) < 1.6:
            continue
        key = rng.choice(["decor_tree_pine", "decor_tree_pine", "decor_tree_pine", "decor_tree_round"])
        place(key, MODELS + "/terrain/%s.glb" % key, Vector((p.x, p.y, h)), rng.uniform(0, 6.28), rng.uniform(1.5, 2.6), C_P)
        trees += 1
        if trees > 1400:
            break
    dice = 0
    for k in range(900):
        p = Vector((rng.uniform(-60, 60), rng.uniform(8, 100)))
        h = level_at(xs, ys, H, p)
        if h is None or h < 1.5:
            continue
        d20(d20_mb, Vector((p.x, p.y, h)), rng.uniform(1.4, 2.4), k)
        dice += 1
        if dice >= 9:
            break
    # brass map pins along the edges of the road on the board, every couple of metres
    for pts in (r0, r1):
        for k in range(4, len(pts) - 2, 9):
            a_, b_ = pts[k - 1], pts[k + 1]
            t_ = (b_ - a_).normalized()
            n_ = Vector((-t_.y, t_.x))
            for side in (1, -1):
                q = pts[k] + n_ * side * 0.62
                place("decor_pins", MODELS + "/terrain/decor_pins.glb", Vector((q.x, q.y, 0.0)), rng.uniform(0, 6.28), 0.8, C_P)
    # dressing on the board plateau
    road_all = r0x + r1x
    sock_c = [cell_c(c, r) + Vector((0.5, -0.5, 0)) for c, r, _ in B["sockets"]]
    hs = B["heartstone"]
    hs_c = cell_c(hs[0], hs[1]) + Vector((0.5, -0.5, 0))
    for k in range(160):
        p = Vector((rng.uniform(-COLS / 2 - 2.5, COLS / 2 + 2.5), rng.uniform(-ROWS / 2 - 2.5, ROWS / 2 + 2.5), 0.0))
        if not inside(p, bo) or min((p - Vector((q.x, q.y, 0))).length for q in road_all[::2]) < 0.85:
            continue
        if min((p - s).length for s in sock_c) < 1.5 or (p - hs_c).length < 1.6:
            continue
        key = rng.choice(["decor_tree_pine", "decor_tree_round", "decor_shrub", "decor_grass", "decor_grass", "decor_flowers", "decor_flowers"])
        place(key, MODELS + "/terrain/%s.glb" % key, p, rng.uniform(0, 6.28), rng.uniform(0.9, 1.4), C_P)
    top_mb.obj("Tops", MATS["grass"], C_T)
    wall_mb.obj("Cliffs", MATS["cliff"], C_T)
    road_mb.obj("Road", MATS["paper"], C_T)
    deck_mb.obj("BridgeDecks", MATS["paper"], C_T)
    rope_mb.obj("BridgeRopes", MATS["paper"], C_T)
    d20_mb.obj("Dice", MATS["paper"], C_T)
    foil_mb.obj("FoilRiver", MATS["foil"], C_T)
    fl.obj("CanyonFloor", MATS["paper"], C_T)
    mt.obj("PaperMountains", MATS["paper"], C_T)
    return {"trees": trees, "dice": dice, "tops": len(top_mb.faces), "walls": len(wall_mb.faces)}


def save_camera(name):
    sc = bpy.context.scene
    bpy.context.view_layer.update()
    cam = sc.camera
    data = {"loc": list(cam.matrix_world.translation), "rot": [list(r) for r in cam.matrix_world.to_3x3()],
            "fov_y": cam.data.angle_y, "w": sc.render.resolution_x, "h": sc.render.resolution_y}
    json.dump(data, open(HERE + "/renders/" + name + "_cam.json", "w"))


# ---------------------------------------------------------------- v2: the board is part of the landscape
LEVELS2 = [-1.7, 0.0, 1.0, 2.0, 3.4, 5.2, 7.4, 10.0, 13.5]


def seg_dist(P, Q, X, Y):
    """Distance from grid nodes (X, Y arrays) to the polyline P (n x 2), and the index of the
    nearest polyline point."""
    import numpy as np
    best = np.full(X.shape, 1e9, np.float32)
    for k in range(len(P) - 1):
        a, b = P[k], P[k + 1]
        ab = b - a
        L2 = float(ab @ ab) + 1e-9
        t = np.clip(((X - a[0]) * ab[0] + (Y - a[1]) * ab[1]) / L2, 0, 1)
        dx = X - (a[0] + t * ab[0])
        dy = Y - (a[1] + t * ab[1])
        best = np.minimum(best, np.sqrt(dx * dx + dy * dy))
    return best


def world_field2(roads, river_pts, res=0.4, box=(-70.0, 70.0, -34.0, 110.0), max_span=7.5):
    """One height field for the board and the world round it. The roads stay at the board's
    level with shoulders, the socket blocks stand at their game height, the Heartstone's block
    is level; everywhere else noise makes plateaus and gorges, so canyons cut through the play
    area too. Where a gorge crosses a road for no more than `max_span` m the road crosses on a
    bridge; a longer one is filled in."""
    import numpy as np
    x0, x1, y0, y1 = box
    xs = np.arange(x0, x1 + 1e-6, res).astype(np.float32)
    ys = np.arange(y0, y1 + 1e-6, res).astype(np.float32)
    X, Y = np.meshgrid(xs, ys)
    H = np.zeros(X.shape, np.float32)
    for i, y in enumerate(ys):
        for j, x in enumerate(xs):
            n1 = _fbm(x * 0.05, y * 0.05, 1.3)
            n2 = _fbm(x * 0.12, y * 0.12, 7.7, 3)
            ridge = abs(noise.noise(Vector((x * 0.05, y * 0.05, 3.3))))
            gorge = abs(noise.noise(Vector((x * 0.085, y * 0.085, 8.8))))
            d = math.hypot(x / 1.25, y / 1.0)
            h = 0.5 + 2.6 * n1 + 0.5 * n2 + 0.16 * max(0.0, d - 13.0)
            if ridge < 0.075 or (d < 16.0 and gorge < 0.085):
                h -= 12.0
            if y < -8.0:
                h = min(h, -0.2 - 0.12 * (-8.0 - y))
            H[i, j] = h
    # the play area: away from the road and the sockets the ground is never at the road's level:
    # it drops to a low terrace or a gorge, or rises to a plateau, so the road runs along raised
    # causeways with cliffs on both sides and the sockets stand as pillars
    inb = (np.abs(X) < COLS / 2 + 1.5) & (np.abs(Y) < ROWS / 2 + 1.5)
    pick = np.zeros(X.shape, np.float32)
    for i, y in enumerate(ys):
        for j, x in enumerate(xs):
            if inb[i, j]:
                pick[i, j] = noise.noise(Vector((x * 0.16, y * 0.16, 21.0))) + 0.3 * noise.noise(Vector((x * 0.4, y * 0.4, 5.0)))
    free = np.where(pick < -0.3, -0.9, np.where(pick < -0.1, -9.0, np.where(pick < 0.22, 0.35, 1.3))).astype(np.float32)
    H = np.where(inb, free, H)
    rp = np.array([(p.x, p.y) for p in river_pts], np.float32)
    dr = seg_dist(rp, None, X, Y)
    inb0 = (np.abs(X) < COLS / 2 + 2) & (np.abs(Y) < ROWS / 2 + 2)
    H = np.where(dr < np.where(inb0, 2.4, 3.0) + 0.8 * np.sin(X * 0.21 + Y * 0.13), -9.0, H)
    # sockets and the Heartstone
    for col, row, lvl in B["sockets"]:
        cen = cell_c(col, row) + Vector((0.5, -0.5, 0))
        m = (np.abs(X - cen.x) < 1.25) & (np.abs(Y - cen.y) < 1.25)
        H = np.where(m, [0.35, 1.35, 2.35][lvl], H)
        ring = (np.abs(X - cen.x) < 1.4) & (np.abs(Y - cen.y) < 1.4) & ~m
        H = np.where(ring & (H < 0.0), 0.35, H)
    hs = B["heartstone"]
    hc = cell_c(hs[0], hs[1]) + Vector((0.5, -0.5, 0))
    m = (np.abs(X - hc.x) < 1.6) & (np.abs(Y - hc.y) < 1.6)
    H = np.where(m, 0.35, H)
    raw = H.copy()
    # roads with shoulders, bridging short gorges
    bridges = []
    for pts in roads:
        P = np.array([(p.x, p.y) for p in pts], np.float32)
        # the gorge under each road point, from the field before the roads
        under = []
        for p in pts:
            j = int(round((p.x - x0) / res))
            i = int(round((p.y - y0) / res))
            under.append(0 <= i < len(ys) and 0 <= j < len(xs) and raw[i, j] < -1.0 and not
                         any(abs(p.x - (cell_c(c, r) + Vector((0.5, -0.5, 0))).x) < 1.8 and abs(p.y - (cell_c(c, r) + Vector((0.5, -0.5, 0))).y) < 1.8 for c, r, _ in B["sockets"]))
        spans, k = [], 0
        while k < len(pts):
            if under[k]:
                s0 = k
                while k < len(pts) and under[k]:
                    k += 1
                span = sum((pts[q + 1] - pts[q]).length for q in range(s0, min(k, len(pts) - 1)))
                if 1.0 < span <= max_span and s0 > 0 and k < len(pts):
                    spans.append((s0, k))
            k += 1
        keep = np.ones(len(pts), bool)
        for s0, s1 in spans:
            keep[max(0, s0 - 1):min(len(pts), s1 + 1)] = False
            bridges.append(pts[max(0, s0 - 2):min(len(pts), s1 + 2)])
        # distance to the road, one unbroken stretch at a time (a straight chord across a
        # bridge gap would dam the gorge)
        d_land = np.full(X.shape, 1e9, np.float32)
        k0 = None
        for k in range(len(pts) + 1):
            on = k < len(pts) and keep[k]
            if on and k0 is None:
                k0 = k
            if not on and k0 is not None:
                if k - k0 >= 2:
                    d_land = np.minimum(d_land, seg_dist(P[k0:k], None, X, Y))
                k0 = None
        # road bed: level 0 under the road and its shoulders, and no plateau over it
        H = np.where(d_land < 0.78, 0.35, H)
        H = np.where((d_land < 0.95) & (H < 0.0), 0.35, H)
        # and keep the gorge open under each bridge
        for s0, s1 in spans:
            Pb = P[max(0, s0 - 1):s1 + 1]
            if len(Pb) >= 2:
                db = seg_dist(Pb, None, X, Y)
                H = np.where((db < 1.1) & (d_land > 1.25), np.minimum(H, -9.0), H)
    return xs, ys, H, bridges


def terraces2(top_mb, wall_mb, xs, ys, H):
    global LEVELS
    old = LEVELS
    LEVELS = LEVELS2
    try:
        terraces(top_mb, wall_mb, xs, ys, H)
    finally:
        LEVELS = old


def level_at2(xs, ys, H, p):
    global LEVELS
    old = LEVELS
    LEVELS = LEVELS2
    try:
        return level_at(xs, ys, H, p)
    finally:
        LEVELS = old


def build_world2(seed=11):
    global rng
    rng = random.Random(seed)
    fresh_scene()
    make_materials()
    MATS["road"] = vc_mat("DIO_road", rough=0.9)
    add_cobbles(MATS["road"])
    C_T, C_P = coll("Terrain"), coll("Props")
    top_mb, wall_mb, road_mb, deck_mb, rope_mb, d20_mb, foil_mb = (MeshBuilder() for _ in range(7))
    r0, r1 = route_pts(0), route_pts(1)
    r0x = extend(r0, Vector((-1, 0.15)), 30.0, seed=1.0)
    r1x = extend(r1, Vector((0.1, 1)), 34.0, seed=2.0)
    if "river_world" in B:
        riv = [Vector((x, -z)) for x, z in B["river_world"]]
        riv = spline([Vector((9.0, 110)), Vector((4.0, 75)), Vector((7.0, 52)), riv[0]], 0.5)[:-1] + riv
    else:
        river_ctrl = [Vector(p) for p in [(15.5, -40), (13.0, -16), (12.2, -6), (12.5, 2), (14.0, 9), (12.0, 18), (15.0, 30), (11.0, 48), (17.0, 70), (12.0, 95), (18.0, 125)]]
        riv = spline(river_ctrl)
    xs, ys, H, bridges = world_field2([r0x, r1x], riv, max_span=16.0)
    terraces2(top_mb, wall_mb, xs, ys, H)

    bridge_pts = set()
    for bp in bridges:
        for q in bp[1:-1]:
            bridge_pts.add((round(q.x, 3), round(q.y, 3)))

    def on_bridge(p):
        return (round(p.x, 3), round(p.y, 3)) in bridge_pts

    for pts, z in ((r0x, 0.02), (r1x, 0.024)):
        run = []
        for p in pts:
            if on_bridge(p):
                if len(run) > 1:
                    road2(road_mb, run, z)
                run = []
            else:
                run.append(p)
        if len(run) > 1:
            road2(road_mb, run, z)
    for bp in bridges:
        bridge_along(deck_mb, rope_mb, bp, 0.05, width=1.0)
    fl = MeshBuilder()
    R = 160
    ids = [fl.v((x * R, y * R + 40, CANYON_Z - 0.3)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    fl.f(ids, srgb("#3e2b1c"))
    river(foil_mb, riv, 3.2, CANYON_Z - 0.25)
    # forests, rocks and crates; dice on the high ground
    trees = 0
    road_all = r0x + r1x
    sock_c = [cell_c(c, r) + Vector((0.5, -0.5, 0)) for c, r, _ in B["sockets"]]
    hs = B["heartstone"]
    hs_c = cell_c(hs[0], hs[1]) + Vector((0.5, -0.5, 0))
    for k in range(14000):
        if k % 3 == 0:
            p = Vector((rng.uniform(-COLS / 2 - 2, COLS / 2 + 2), rng.uniform(-ROWS / 2 - 2, ROWS / 2 + 2)))
        else:
            p = Vector((rng.uniform(xs[0], xs[-1]), rng.uniform(ys[0], ys[-1])))
        inb = abs(p.x) < COLS / 2 + 1 and abs(p.y) < ROWS / 2 + 1
        if p.y < -14 and rng.random() < 0.6:
            continue
        forest = noise.noise(Vector((p.x * 0.07, p.y * 0.07, 11.0)))
        if forest < (0.05 if inb else -0.05):
            if not (inb and forest > -0.25 and rng.random() < 0.3):
                continue
        h = level_at2(xs, ys, H, p)
        if h is None:
            continue
        if min((p - q).length for q in road_all[::3]) < 1.15:
            continue
        p3 = Vector((p.x, p.y, 0))
        if min((p3 - s).length for s in sock_c) < 1.6 or (p3 - hs_c).length < 1.8:
            continue
        r_ = rng.random()
        if inb and r_ < 0.25:
            key = rng.choice(["decor_shrub", "decor_grass", "decor_flowers", "decor_scrap"])
            sc_ = rng.uniform(0.9, 1.3)
        elif h < -1.0:
            if rng.random() > 0.35:
                continue
            key = rng.choice(["decor_shrub", "decor_tree_round", "decor_scrap"])
            sc_ = rng.uniform(1.2, 2.0)
        else:
            key = rng.choice(["decor_tree_pine", "decor_tree_pine", "decor_tree_pine", "decor_tree_round"])
            sc_ = rng.uniform(1.3, 2.3) if not inb else rng.uniform(1.0, 1.6)
        place(key, MODELS + "/terrain/%s.glb" % key, Vector((p.x, p.y, h)), rng.uniform(0, 6.28), sc_, C_P)
        trees += 1
        if trees > 2200:
            break
    rocks = 0
    for k in range(9000):
        p = Vector((rng.uniform(-45, 45), rng.uniform(-20, 70)))
        h = level_at2(xs, ys, H, p)
        cl = noise.noise(Vector((p.x * 0.12, p.y * 0.12, 31.0)))
        if cl < 0.18:
            continue
        if h is None:
            # on the canyon floor
            j_ = int(round((p.x - xs[0]) / (xs[1] - xs[0])))
            i_ = int(round((p.y - ys[0]) / (ys[1] - ys[0])))
            if not (0 <= i_ < H.shape[0] and 0 <= j_ < H.shape[1]) or H[i_, j_] > -2.0:
                continue
            h = CANYON_Z - 0.3
        if min((p - q).length for q in road_all[::3]) < 1.0:
            continue
        p3 = Vector((p.x, p.y, 0))
        if min((p3 - s).length for s in sock_c) < 1.6 or (p3 - hs_c).length < 1.8:
            continue
        rock(d20_mb, Vector((p.x, p.y, h)), rng.uniform(0.18, 0.7) * (1.6 if h < -2 else 1.0), k)
        rocks += 1
        if rocks >= 650:
            break
    dice = 0
    for k in range(1200):
        p = Vector((rng.uniform(-50, 50), rng.uniform(6, 80)))
        h = level_at2(xs, ys, H, p)
        if h is None or h < 2.0:
            continue
        d20(d20_mb, Vector((p.x, p.y, h)), rng.uniform(1.3, 2.2), k)
        dice += 1
        if dice >= 10:
            break
    for pts in (r0, r1):
        for k in range(6, len(pts) - 2, 40):
            if True:
                continue
                continue
            a_, b_ = pts[k - 1], pts[k + 1]
            t_ = (b_ - a_).normalized()
            n_ = Vector((-t_.y, t_.x))
            for side in (1, -1):
                q = pts[k] + n_ * side * 0.62
                place("decor_pins", MODELS + "/terrain/decor_pins.glb", Vector((q.x, q.y, 0.0)), rng.uniform(0, 6.28), 0.8, C_P)
    mt = MeshBuilder()
    for layer, (dist, hmin, hmax, colr) in enumerate(((120, 18, 30, "#9c8a72"), (145, 24, 40, "#a99d8d"), (175, 30, 52, "#b8b3ab"))):
        n = 80
        prev = None
        for i in range(n + 1):
            a = math.radians(10 + 200 * i / n)
            hh = hmin + (hmax - hmin) * (0.5 + 0.5 * noise.noise(Vector((i * 0.21, layer * 3.0, 0.5))))
            p = Vector((math.cos(a) * dist * 1.25, math.sin(a) * dist))
            lo = mt.v((p.x, p.y, CANYON_Z))
            hi = mt.v((p.x, p.y, hh))
            if prev:
                mt.f([prev[0], lo, hi, prev[1]], [srgb(colr)] * 2 + [shade(srgb(colr), 1.08)] * 2)
            prev = (lo, hi)
    top_mb.obj("Tops", MATS["grass"], C_T)
    wall_mb.obj("Cliffs", MATS["cliff"], C_T)
    road_mb.obj("Road", MATS["road"], C_T)
    deck_mb.obj("BridgeDecks", MATS["paper"], C_T)
    rope_mb.obj("BridgeRopes", MATS["paper"], C_T)
    d20_mb.obj("Dice", MATS["paper"], C_T)
    foil_mb.obj("FoilRiver", MATS["foil"], C_T)
    fl.obj("CanyonFloor", MATS["paper"], C_T)
    mt.obj("PaperMountains", MATS["paper"], C_T)
    return {"trees": trees, "dice": dice, "rocks": rocks, "bridges": len(bridges), "tops": len(top_mb.faces), "walls": len(wall_mb.faces)}


def road2(mb, pts, z):
    """The road as packed kraft-paper cobbles: ragged edges, a darker rim and blotchy stones."""
    left, right = [], []
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        t = (b - a).normalized()
        n = Vector((-t.y, t.x))
        wl = 0.55 + 0.08 * noise.noise(Vector((p.x * 2.1, p.y * 2.1, 1.0)))
        wr = 0.55 + 0.08 * noise.noise(Vector((p.x * 2.1, p.y * 2.1, 5.0)))
        left.append((mb.v((p.x + n.x * wl, p.y + n.y * wl, z)), mb.v((p.x + n.x * wl * 0.55, p.y + n.y * wl * 0.55, z + 0.003))))
        right.append((mb.v((p.x - n.x * wr, p.y - n.y * wr, z)), mb.v((p.x - n.x * wr * 0.55, p.y - n.y * wr * 0.55, z + 0.003))))

    def cob(p):
        v = noise.noise(Vector((p[0] * 3.1, p[1] * 3.1, 2.0)))
        return lerpc(srgb("#c9a676"), srgb("#e2c79c"), 0.5 + 0.5 * v)
    V = mb.verts
    for i in range(len(pts) - 1):
        lo0, li0 = left[i]
        lo1, li1 = left[i + 1]
        ro0, ri0 = right[i]
        ro1, ri1 = right[i + 1]
        rim = srgb("#a5824f")
        mb.f([lo0, lo1, li1, li0], [rim, rim, cob(V[li1]), cob(V[li0])])
        mb.f([li0, li1, ri1, ri0], [cob(V[li0]), cob(V[li1]), cob(V[ri1]), cob(V[ri0])])
        mb.f([ri0, ri1, ro1, ro0], [cob(V[ri0]), cob(V[ri1]), rim, rim])


# ---------------------------------------------------------------- cartoon shading
def _toon_group():
    """The cartoon light model as a node group: diffuse light stepped into three bands (lit, mid,
    shadow) and a warm rim on the silhouette. In Godot this is a `light()` function plus a
    fresnel term in `fragment()`, both fine in the Compatibility renderer."""
    g = bpy.data.node_groups.get("DIO_Toon")
    if g:
        return g
    g = bpy.data.node_groups.new("DIO_Toon", "ShaderNodeTree")
    g.interface.new_socket("Color", in_out="INPUT", socket_type="NodeSocketColor")
    g.interface.new_socket("Normal", in_out="INPUT", socket_type="NodeSocketVector")
    g.interface.new_socket("Shader", in_out="OUTPUT", socket_type="NodeSocketShader")
    n = g.nodes
    L = g.links
    gi = n.new("NodeGroupInput")
    go = n.new("NodeGroupOutput")
    dif = n.new("ShaderNodeBsdfDiffuse")
    dif.inputs["Color"].default_value = (1, 1, 1, 1)
    L.new(gi.outputs["Normal"], dif.inputs["Normal"])
    s2r = n.new("ShaderNodeShaderToRGB")
    L.new(dif.outputs[0], s2r.inputs[0])
    bw = n.new("ShaderNodeRGBToBW")
    L.new(s2r.outputs["Color"], bw.inputs[0])
    ramp = n.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    e = ramp.color_ramp.elements
    e[0].position = 0.0
    e[0].color = (0.42, 0.40, 0.52, 1)
    e[1].position = 0.18
    e[1].color = (0.74, 0.70, 0.70, 1)
    e3 = e.new(0.55)
    e3.color = (1.0, 0.97, 0.9, 1)
    L.new(bw.outputs[0], ramp.inputs[0])
    mul = n.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    L.new(gi.outputs["Color"], mul.inputs[6])
    L.new(ramp.outputs[0], mul.inputs[7])
    lw = n.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    L.new(gi.outputs["Normal"], lw.inputs["Normal"])
    rr = n.new("ShaderNodeValToRGB")
    rr.color_ramp.interpolation = "CONSTANT"
    rr.color_ramp.elements[0].color = (0, 0, 0, 1)
    rr.color_ramp.elements[1].position = 0.72
    rr.color_ramp.elements[1].color = (0.32, 0.22, 0.10, 1)
    L.new(lw.outputs["Facing"], rr.inputs[0])
    add = n.new("ShaderNodeMix")
    add.data_type = "RGBA"
    add.blend_type = "ADD"
    add.inputs[0].default_value = 1.0
    L.new(mul.outputs[2], add.inputs[6])
    L.new(rr.outputs[0], add.inputs[7])
    em = n.new("ShaderNodeEmission")
    L.new(add.outputs[2], em.inputs[0])
    L.new(em.outputs[0], go.inputs["Shader"])
    return g


def toonify_material(m):
    """Swaps a material's Principled BSDF for the cartoon light model, keeping its colour and
    bump (and keeping emission for glowing parts)."""
    if m is None or not m.use_nodes or m.get("dio_toon"):
        return
    nt = m.node_tree
    bs = [x for x in nt.nodes if x.bl_idname == "ShaderNodeBsdfPrincipled"]
    out = [x for x in nt.nodes if x.bl_idname == "ShaderNodeOutputMaterial"]
    if not bs or not out:
        return
    b = bs[0]
    grp = nt.nodes.new("ShaderNodeGroup")
    grp.node_tree = _toon_group()
    bc = b.inputs["Base Color"]
    if bc.links:
        nt.links.new(bc.links[0].from_socket, grp.inputs["Color"])
    else:
        grp.inputs["Color"].default_value = bc.default_value
    nn = b.inputs["Normal"]
    if nn.links:
        nt.links.new(nn.links[0].from_socket, grp.inputs["Normal"])
    else:
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        nt.links.new(geo.outputs["Normal"], grp.inputs["Normal"])
    shader = grp.outputs["Shader"]
    es = b.inputs["Emission Strength"].default_value
    ec = b.inputs["Emission Color"]
    if es > 0.0 and (ec.links or sum(ec.default_value[:3]) > 0.0):
        em = nt.nodes.new("ShaderNodeEmission")
        if ec.links:
            nt.links.new(ec.links[0].from_socket, em.inputs[0])
        else:
            em.inputs[0].default_value = ec.default_value
        em.inputs[1].default_value = es
        addn = nt.nodes.new("ShaderNodeAddShader")
        nt.links.new(shader, addn.inputs[0])
        nt.links.new(em.outputs[0], addn.inputs[1])
        shader = addn.outputs[0]
    for o in out:
        nt.links.new(shader, o.inputs["Surface"])
    m["dio_toon"] = True


def outline_material():
    m = bpy.data.materials.get("DIO_outline") or bpy.data.materials.new("DIO_outline")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = (*srgb("#2a170c"), 1)
    nt.links.new(e.outputs[0], o.inputs[0])
    m.use_backface_culling = True
    return m


def add_outline(o, thickness):
    """Inverted hull: a shell pushed out along the normals, only its back faces drawn, in a dark
    ink colour. In Godot: a next_pass material with cull_front that grows the vertices."""
    if o.type != "MESH" or o.modifiers.get("DIO_outline"):
        return
    om = outline_material()
    if om.name not in [m.name for m in o.data.materials if m]:
        o.data.materials.append(om)
    idx = [m.name if m else "" for m in o.data.materials].index(om.name)
    mod = o.modifiers.new("DIO_outline", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 1.0
    mod.use_flip_normals = True
    mod.use_rim = False
    mod.material_offset = idx


def toonify_scene(outlines=True):
    sc = bpy.context.scene
    seen = set()
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            continue
        for m in o.data.materials:
            if m and m.name not in seen:
                seen.add(m.name)
                toonify_material(m)
    if outlines:
        for name, t in (("Cliffs", 0.03), ("Tops", 0.02), ("Road", 0.012), ("BridgeDecks", 0.012), ("Dice", 0.03)):
            o = bpy.data.objects.get(name)
            if o:
                add_outline(o, t)
        for c in bpy.data.collections:
            if c.name.startswith("P_"):
                for o in c.all_objects:
                    add_outline(o, 0.02 if "tree" not in c.name else 0.035)
    return len(seen)
