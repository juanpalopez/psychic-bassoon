
# godot_kit.py (run in Blender: blender -b -P assets-src/papercraft/godot_kit.py) - the board tiles, Heartstone, spawn ink and decor exported to godot/assets/models.
# Every piece has its origin at the centre of its base. Thin paper is one-sided here; the
# Godot paper and ink shaders draw both sides. Material names starting PK_ pick a
# shader in Godot (render/paper_look.gd); any other material becomes plain paper in its colour.
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
WT = os.path.normpath(os.path.join(HERE, "..", "..", "godot", "assets", "models"))
rng = random.Random(11)
scn = bpy.data.scenes.get("Godot_Kit") or bpy.data.scenes.new("Godot_Kit")
bpy.context.window.scene = scn
for o in list(scn.objects): bpy.data.objects.remove(o, do_unlink=True)

def srgb_to_lin(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)
def mat(name, srgb=None, emis=0.0):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name); m.use_nodes = True
    if srgb is not None:
        lin = srgb_to_lin(srgb); b = m.node_tree.nodes.get("Principled BSDF")
        if b is None:
            m.node_tree.nodes.clear(); b = m.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
            out = m.node_tree.nodes.new("ShaderNodeOutputMaterial"); m.node_tree.links.new(b.outputs[0], out.inputs[0])
        b.inputs["Base Color"].default_value = (*lin, 1); b.inputs["Roughness"].default_value = 0.85
        if emis:
            b.inputs["Emission Color"].default_value = (*lin, 1); b.inputs["Emission Strength"].default_value = emis
        m.diffuse_color = (*lin, 1)
    return m
for k in ("PK_CuttingMat", "PK_Corrugated", "PK_Greyboard", "PK_PencilRing", "PK_DeskWood", "PK_BlotInk", "PK_PaperVC"): mat(k)

class Piece:
    def __init__(s): s.bm = bmesh.new(); s.mats = []; s.uv = s.bm.loops.layers.uv.verify()
    def m(s, name):
        if name not in s.mats: s.mats.append(name)
        return s.mats.index(name)
    def face(s, verts, mi, uvs=None):
        f = s.bm.faces.new([s.bm.verts.new(v) if not isinstance(v, bmesh.types.BMVert) else v for v in verts])
        f.material_index = mi
        if uvs:
            for lp, uv in zip(f.loops, uvs): lp[s.uv].uv = uv
        return f
    def box(s, lo, hi, mi, uv_v=None, drop_bottom=False, yaw=0.0):
        (x0, y0, z0), (x1, y1, z1) = lo, hi
        c = Vector(((x0 + x1) / 2, (y0 + y1) / 2, 0))
        R = Matrix.Rotation(yaw, 3, 'Z')
        P = lambda x, y, z: (R @ (Vector((x, y, 0)) - c)) + c + Vector((0, 0, z))
        v = [s.bm.verts.new(P(x, y, z)) for z in (z0, z1) for (x, y) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
        faces = [(4, 5, 6, 7)] + ([] if drop_bottom else [(3, 2, 1, 0)])
        sides = [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        for q in faces:
            f = s.bm.faces.new([v[i] for i in q]); f.material_index = mi
            for lp in f.loops: lp[s.uv].uv = (lp.vert.co.x, lp.vert.co.y)
        for q in sides:
            f = s.bm.faces.new([v[i] for i in q]); f.material_index = mi
            for lp, (uu, vv) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))): lp[s.uv].uv = (uu, vv)
    def cyl(s, base, axis, r0, r1, length, segs, mi, cap0=True, cap1=True, phase=0.0):
        axis = Vector(axis).normalized(); base = Vector(base)
        ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
        u = axis.cross(ref).normalized(); w = axis.cross(u)
        ring = lambda r, d: [s.bm.verts.new(base + axis * d + (u * math.cos(phase + 2 * math.pi * i / segs) + w * math.sin(phase + 2 * math.pi * i / segs)) * r) for i in range(segs)]
        a = ring(r0, 0.0)
        b = ring(r1, length) if r1 > 0 else [s.bm.verts.new(base + axis * length)]
        for i in range(segs):
            j = (i + 1) % segs
            f = s.bm.faces.new((a[i], a[j], b[j], b[i]) if len(b) > 1 else (a[i], a[j], b[0])); f.material_index = mi
        if cap0: s.bm.faces.new(list(reversed(a))).material_index = mi
        if cap1 and len(b) > 1: s.bm.faces.new(b).material_index = mi
    def export(s, rel, smooth=False):
        bm = s.bm
        # every non-PK_ material becomes a vertex colour on one shared PK_PaperVC surface, so a
        # prop is one draw call; alpha 1 marks faces that glow (the Heartstone's heart)
        if any(not m_.startswith("PK_") for m_ in s.mats):
            col = bm.loops.layers.float_color.get("Col") or bm.loops.layers.float_color.new("Col")
            vc = s.m("PK_PaperVC")
            for f in bm.faces:
                name = s.mats[f.material_index]
                if name.startswith("PK_"):
                    c = (1.0, 1.0, 1.0, 0.0)
                else:
                    mm_ = bpy.data.materials[name]; b_ = mm_.node_tree.nodes.get("Principled BSDF")
                    rgb = tuple(b_.inputs["Base Color"].default_value)[:3]
                    glow = 1.0 if b_.inputs["Emission Strength"].default_value > 0 else 0.0
                    c = (*rgb, glow); f.material_index = vc
                for lp in f.loops: lp[col] = c
            used = sorted({f.material_index for f in bm.faces})
            remap = {old_i: new_i for new_i, old_i in enumerate(used)}
            for f in bm.faces: f.material_index = remap[f.material_index]
            s.mats = [s.mats[i] for i in used]
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        for f in bm.faces: f.smooth = smooth
        name = os.path.splitext(os.path.basename(rel))[0]
        me = bpy.data.meshes.get(name)
        if me: bpy.data.meshes.remove(me)
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        for k in s.mats: me.materials.append(bpy.data.materials[k])
        o = bpy.data.objects.new(name, me); scn.collection.objects.link(o)
        for x in scn.objects: x.select_set(False)
        o.select_set(True); bpy.context.view_layer.objects.active = o
        path = os.path.join(WT, rel); os.makedirs(os.path.dirname(path), exist_ok=True)
        if me.color_attributes:
            me.color_attributes.active_color = me.color_attributes[0]
        opts = dict(filepath=path, export_format='GLB', use_selection=True, use_active_scene=True,
                    export_yup=True, export_apply=True, export_materials='EXPORT', export_cameras=False,
                    export_lights=False, export_animations=False)
        try:
            bpy.ops.export_scene.gltf(export_vertex_color='NAME', export_vertex_color_name='Col', export_all_vertex_colors=False, **opts)
        except TypeError:
            bpy.ops.export_scene.gltf(export_colors=True, **opts)
        o.location = (len(REPORT) * 2.5, -4.0, 0)
        REPORT[rel] = sum(len(p.vertices) - 2 for p in me.polygons)
REPORT = {}

# ---------- board tiles (1 x 1 cell, centred, walk surface at 0) ----------
for rel in ("terrain/terrain_mat.glb", "terrain/terrain_lane.glb"):
    p = Piece(); p.box((-0.5, -0.5, -0.12), (0.5, 0.5, 0.0), p.m("PK_CuttingMat"), drop_bottom=True); p.export(rel)

p = Piece(); mi = p.m("PK_Corrugated")
jit = [(0.0, 0.0), (0.012, -0.008), (-0.006, 0.010), (0.009, 0.004), (-0.010, -0.006)]
for k, (jx, jy) in enumerate(jit):
    p.box((-0.5 + jx, -0.5 + jy, 0.2 * k), (0.5 + jx, 0.5 + jy, 0.2 * k + 0.2), mi)
p.export("terrain/terrain_cardboard_l1.glb")

p = Piece(); mi = p.m("PK_Greyboard")
p.box((-0.5, -0.5, 0.0), (0.5, 0.5, 1.1), mi)
p.box((-0.5, -0.43, 1.1), (0.43, 0.5, 2.0), mi)   # inset on +X and -Y (Godot +X, +Z); the board turns it outward
p.export("terrain/terrain_paperboard_l2.glb")

p = Piece(); mi = p.m("PK_PencilRing"); n = 48; ro, w, h = 0.80, 0.065, 0.004
outer = [p.bm.verts.new((math.cos(2 * math.pi * i / n) * ro, math.sin(2 * math.pi * i / n) * ro, h)) for i in range(n)]
inner = [p.bm.verts.new((math.cos(2 * math.pi * i / n) * (ro - w), math.sin(2 * math.pi * i / n) * (ro - w), h)) for i in range(n)]
for i in range(n):
    j = (i + 1) % n
    p.face([inner[i], inner[j], outer[j], outer[i]], mi, [(i / n * 5.0, 0), ((i + 1) / n * 5.0, 0), ((i + 1) / n * 5.0, 1), (i / n * 5.0, 1)])
for a in (0, 0.5 * math.pi, math.pi, 1.5 * math.pi):
    ca, sa = math.cos(a), math.sin(a); tx, ty = -sa, ca
    pts = [(ca * rr + tx * ww, sa * rr + ty * ww, h) for rr, ww in ((ro - w + 0.01, -0.024), (ro - w + 0.01, 0.024), (ro - w - 0.15, 0.018), (ro - w - 0.15, -0.018))]
    p.face(pts, mi, [(0.5, 0.5)] * 4)
p.export("terrain/overlay_socket_empty_2x2.glb")

DESK = (-0.22, -0.12)
p = Piece(); p.box((-0.5, -0.5, DESK[0]), (0.5, 0.5, DESK[1]), p.m("PK_DeskWood"), drop_bottom=True); p.export("terrain/skirt_desk.glb")
mat("Paper_Eraser", (0.93, 0.55, 0.58)); mat("Paper_Sleeve", (0.25, 0.42, 0.75))
p = Piece(); p.box((-0.5, -0.5, DESK[0]), (0.5, 0.5, DESK[1]), p.m("PK_DeskWood"), drop_bottom=True)
p.box((-0.31, -0.16, DESK[1]), (0.31, 0.16, DESK[1] + 0.17), p.m("Paper_Eraser"), yaw=math.radians(20))
p.box((-0.12, -0.165, DESK[1]), (0.22, 0.165, DESK[1] + 0.175), p.m("Paper_Sleeve"), yaw=math.radians(20))
p.export("terrain/skirt_eraser.glb")
mat("Paper_PencilYellow", (0.96, 0.74, 0.16)); mat("Paper_PencilWood", (0.86, 0.70, 0.50)); mat("Paper_Graphite", (0.12, 0.12, 0.13)); mat("Paper_Ferrule", (0.80, 0.72, 0.52))
p = Piece(); p.box((-0.5, -0.5, DESK[0]), (0.5, 0.5, DESK[1]), p.m("PK_DeskWood"), drop_bottom=True)
ax = Vector((math.cos(math.radians(35)), math.sin(math.radians(35)), 0)); r = 0.065; z = DESK[1] + r
start = Vector((0, 0, z)) - ax * 0.62
p.cyl(start - ax * 0.07, ax, r, r, 0.07, 10, p.m("Paper_Eraser"))
p.cyl(start, ax, r * 1.03, r * 1.03, 0.09, 10, p.m("Paper_Ferrule"))
p.cyl(start + ax * 0.09, ax, r, r, 0.95, 6, p.m("Paper_PencilYellow"))
p.cyl(start + ax * 1.04, ax, r, 0.022, 0.16, 6, p.m("Paper_PencilWood"), cap1=False)
p.cyl(start + ax * 1.20, ax, 0.022, 0.0, 0.05, 6, p.m("Paper_Graphite"), cap0=False)
p.export("terrain/skirt_pencil.glb")

# ---------- Heartstone: a folded-paper heart leaning back to face the steep camera ----------
mat("Paper_Heart", (0.80, 0.10, 0.20), emis=1.6); mat("Paper_Cardstock", (0.90, 0.86, 0.78))
p = Piece(); base = p.m("Paper_Cardstock"); n = 16; bot = []; top = []
for i in range(n):
    a = 2 * math.pi * i / n; rr = 0.92 if i % 2 == 0 else 0.84
    bot.append(p.bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, 0.0)))
    top.append(p.bm.verts.new((math.cos(a) * rr * 0.9, math.sin(a) * rr * 0.9, 0.12 + (0.025 if i % 2 else 0.0))))
for i in range(n):
    j = (i + 1) % n; p.face([bot[i], bot[j], top[j], top[i]], base)
cv = p.bm.verts.new((0, 0, 0.16))
for i in range(n): p.face([top[i], top[(i + 1) % n], cv], base)
p.cyl((0, 0, 0.12), (0, 0, 1), 0.30, 0.12, 0.36, 6, base)
heart = p.m("Paper_Heart")
prof = [(0, 0), (0.55, 0.55), (0.85, 1.0), (0.80, 1.35), (0.55, 1.55), (0.25, 1.45), (0, 1.25), (-0.25, 1.45), (-0.55, 1.55), (-0.80, 1.35), (-0.85, 1.0), (-0.55, 0.55)]
lean = Matrix.Translation((0, 0, 0.45)) @ Matrix.Rotation(math.radians(-38), 4, 'X') @ Matrix.Translation((0, 0, -0.45))
ring = [p.bm.verts.new(lean @ Vector((px * 0.95, 0, 0.45 + pz * 0.95))) for px, pz in prof]
fr = p.bm.verts.new(lean @ Vector((0, -0.40, 0.45 + 0.95 * 0.95))); bk = p.bm.verts.new(lean @ Vector((0, 0.40, 0.45 + 0.95 * 0.95)))
for i in range(len(ring)):
    j = (i + 1) % len(ring); p.face([ring[i], ring[j], fr], heart); p.face([ring[j], ring[i], bk], heart)
p.export("towers/heartstone.glb")

# ---------- the Blot at a spawn: ink on the mat, over the edge, and a bottle on the desk (-X) ----------
mat("Paper_Label", (0.92, 0.88, 0.78)); mat("Paper_Cap", (0.10, 0.10, 0.11))
p = Piece(); ink = p.m("PK_BlotInk")
def puddle(cx, cy, rx, ry, z, th, rot=0.0, n=24):
    harm = [(rng.uniform(0.05, 0.15), rng.randint(2, 5), rng.uniform(0, 6.28)) for _ in range(4)]
    e = []; mm = []
    for i in range(n):
        a = 2 * math.pi * i / n; k = 1.0 + sum(hh * math.sin(m_ * a + ph) for hh, m_, ph in harm)
        ex, ey = math.cos(a) * rx * k, math.sin(a) * ry * k
        ex, ey = ex * math.cos(rot) - ey * math.sin(rot), ex * math.sin(rot) + ey * math.cos(rot)
        e.append(p.bm.verts.new((cx + ex, cy + ey, z))); mm.append(p.bm.verts.new((cx + ex * 0.85, cy + ey * 0.85, z + th)))
    c = p.bm.verts.new((cx, cy, z + th * 1.2))
    for i in range(n):
        j = (i + 1) % n; p.face([e[i], e[j], mm[j], mm[i]], ink); p.face([mm[i], mm[j], c], ink)
puddle(-0.05, 0.02, 0.55, 0.36, 0.003, 0.012, rot=0.1)
puddle(0.38, -0.12, 0.18, 0.13, 0.003, 0.010)
p.face([(-0.50, -0.13, 0.002), (-0.50, 0.17, 0.002), (-0.53, 0.19, -0.12), (-0.53, -0.16, -0.12)], ink)
puddle(-1.05, 0.06, 0.55, 0.30, -0.118, 0.012, rot=-0.1)
ax = Vector((-1, 0.25, 0)).normalized(); bz = -0.12 + 0.30
glass = ink
p.cyl(Vector((-1.45, 0.10, bz)), ax, 0.30, 0.30, 0.55, 12, glass)
p.cyl(Vector((-1.45, 0.10, bz)) + ax * 0.55, ax, 0.30, 0.13, 0.14, 12, glass, cap0=False)
p.cyl(Vector((-1.45, 0.10, bz)) - ax * 0.0 + ax * 0.08, ax, 0.305, 0.305, 0.36, 12, p.m("Paper_Label"), cap0=False, cap1=False)
p.bm.normal_update()
p.cyl((-1.25, 0.62, -0.12), (0, 0, 1), 0.14, 0.14, 0.16, 10, p.m("Paper_Cap"))
p.export("terrain/blot_spawn.glb", smooth=True)

# ---------- decor ----------
mat("Paper_Green", (0.44, 0.70, 0.36)); mat("Paper_GreenDark", (0.31, 0.56, 0.29)); mat("Paper_Kraft", (0.72, 0.56, 0.38))
mat("Paper_Lime", (0.62, 0.74, 0.30)); mat("Paper_Olive", (0.44, 0.56, 0.20))
def pleated_cone(p, z0, z1, R, n, light, dark, twist=0.0):
    apex = p.bm.verts.new((0, 0, z1))
    pts = []
    for i in range(2 * n):
        a = twist + math.pi * i / n; rr = R if i % 2 == 0 else R * 0.72
        pts.append(p.bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z0 + (0.0 if i % 2 == 0 else 0.05))))
    for i in range(2 * n):
        j = (i + 1) % (2 * n); p.face([pts[i], pts[j], apex], light if i % 2 == 0 else dark)
    p.face(list(reversed(pts)), dark)
p = Piece(); g1, g2, kr = p.m("Paper_Green"), p.m("Paper_GreenDark"), p.m("Paper_Kraft")
p.cyl((0, 0, 0), (0, 0, 1), 0.07, 0.06, 0.40, 6, kr)
for z0, z1, R, tw in ((0.30, 0.95, 0.58, 0.0), (0.68, 1.25, 0.46, 0.3), (1.00, 1.60, 0.33, 0.1)):
    pleated_cone(p, z0, z1, R, 7, g1, g2, tw)
p.export("terrain/decor_tree_pine.glb")
p = Piece(); g1, g2, kr = p.m("Paper_Lime"), p.m("Paper_Olive"), p.m("Paper_Kraft")
p.cyl((0, 0, 0), (0, 0, 1), 0.07, 0.05, 0.55, 6, kr)
tmp = bmesh.new(); bmesh.ops.create_icosphere(tmp, subdivisions=1, radius=0.5, matrix=Matrix.Translation((0, 0, 0.88)) @ Matrix.Diagonal((1.0, 1.0, 0.82, 1)))
off = len(p.bm.verts); vmap = {v: p.bm.verts.new(v.co + Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03)))) for v in tmp.verts}
for k, f in enumerate(tmp.faces): p.face([vmap[v] for v in f.verts], g1 if k % 3 else g2)
tmp.free(); p.export("terrain/decor_tree_round.glb")
p = Piece(); g1, g2 = p.m("Paper_Green"), p.m("Paper_GreenDark")
for k in range(6):
    a = 2 * math.pi * k / 6 + rng.uniform(-0.3, 0.3); tilt = rng.uniform(0.45, 0.8); L = rng.uniform(0.32, 0.42)
    d = Vector((math.cos(a) * math.cos(tilt), math.sin(a) * math.cos(tilt), math.sin(tilt)))
    side = Vector((-math.sin(a), math.cos(a), 0)) * 0.10
    base = Vector((0, 0, 0.02)); tip = base + d * L; mid = base + d * L * 0.5; crease = Vector((0, 0, -0.035))
    p.face([base, mid + side, tip, mid + crease], g1); p.face([base, mid + crease, tip, mid - side], g2)
p.export("terrain/decor_shrub.glb")
p = Piece(); g1, g2 = p.m("Paper_Lime"), p.m("Paper_Green")
for k in range(9):
    a = -0.9 + 1.8 * k / 8; x = math.sin(a) * 0.16; y = math.cos(a) * 0.05
    h = rng.uniform(0.18, 0.30); lean = Vector((math.sin(a) * 0.07, rng.uniform(-0.03, 0.03), 0))
    p.face([(x - 0.025, y, 0), (x + 0.025, y, 0), Vector((x, y, h)) + lean], g1 if k % 2 else g2)
p.export("terrain/decor_grass.glb")
mat("Paper_Red", (0.86, 0.24, 0.22)); mat("Paper_Yellow", (0.98, 0.82, 0.28)); mat("Paper_White", (0.95, 0.93, 0.88))
p = Piece(); stem = p.m("Paper_Green")
for (fx, fy, fh, col) in ((0.0, 0.0, 0.36, "Paper_Red"), (0.16, 0.08, 0.28, "Paper_Yellow"), (-0.12, 0.10, 0.24, "Paper_White")):
    p.face([(fx - 0.012, fy, 0), (fx + 0.012, fy, 0), (fx + 0.012, fy, fh), (fx - 0.012, fy, fh)], stem)
    ci = p.m(col); c = p.bm.verts.new((fx, fy, fh + 0.02)); pts = []
    for i in range(10):
        a = math.pi * i / 5; rr = 0.10 if i % 2 == 0 else 0.045
        pts.append(p.bm.verts.new((fx + math.cos(a) * rr, fy + math.sin(a) * rr * 0.8, fh + 0.02 + math.sin(a) * 0.04)))
    for i in range(10): p.face([pts[i], pts[(i + 1) % 10], c], ci)
    p.cyl((fx, fy, fh + 0.02), (0, 0, 1), 0.025, 0.025, 0.015, 6, p.m("Paper_Yellow" if col != "Paper_Yellow" else "Paper_Kraft"))
p.export("terrain/decor_flowers.glb")
mat("Paper_ButtonBlue", (0.30, 0.45, 0.70)); mat("Paper_ButtonCream", (0.92, 0.86, 0.72)); mat("Paper_ButtonRust", (0.74, 0.36, 0.24)); mat("Paper_Hole", (0.12, 0.10, 0.09))
p = Piece()
for (bx, by, r, col) in ((0.0, 0.0, 0.19, "Paper_ButtonBlue"), (0.30, 0.16, 0.14, "Paper_ButtonCream"), (-0.12, 0.28, 0.12, "Paper_ButtonRust")):
    p.cyl((bx, by, 0), (0, 0, 1), r, r * 0.92, 0.05, 14, p.m(col))
    for hx, hy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        p.cyl((bx + hx * r * 0.22, by + hy * r * 0.22, 0.045), (0, 0, 1), r * 0.1, r * 0.1, 0.008, 6, p.m("Paper_Hole"))
p.export("terrain/decor_buttons.glb")
mat("Paper_PinMetal", (0.78, 0.78, 0.80))
p = Piece()
for (px, py, col, lie) in ((0.0, 0.0, "Paper_Red", False), (0.32, 0.18, "Paper_ButtonBlue", True)):
    if lie:
        ax = Vector((0.8, 0.6, 0)).normalized(); c0 = Vector((px, py, 0.09))
        p.cyl(c0, ax, 0.09, 0.07, 0.16, 10, p.m(col)); p.cyl(c0 + ax * 0.16, ax, 0.12, 0.12, 0.03, 10, p.m(col))
        p.cyl(c0 + ax * 0.19, ax, 0.015, 0.0, 0.22, 5, p.m("Paper_PinMetal"), cap0=False)
    else:
        p.cyl((px, py, 0.0), (0, 0, 1), 0.015, 0.015, 0.06, 5, p.m("Paper_PinMetal"))
        p.cyl((px, py, 0.06), (0, 0, 1), 0.13, 0.13, 0.03, 12, p.m(col)); p.cyl((px, py, 0.09), (0, 0, 1), 0.08, 0.06, 0.14, 10, p.m(col))
p.export("terrain/decor_pins.glb")
mat("Paper_Glue", (0.84, 0.83, 0.78))
p = Piece(); gl = p.m("Paper_Glue"); n = 20; e = []; mm = []
harm = [(rng.uniform(0.06, 0.16), rng.randint(2, 5), rng.uniform(0, 6.28)) for _ in range(4)]
for i in range(n):
    a = 2 * math.pi * i / n; k = 1.0 + sum(hh * math.sin(m_ * a + ph) for hh, m_, ph in harm)
    e.append(p.bm.verts.new((math.cos(a) * 0.28 * k, math.sin(a) * 0.20 * k, 0.0))); mm.append(p.bm.verts.new((math.cos(a) * 0.24 * k, math.sin(a) * 0.17 * k, 0.025)))
c = p.bm.verts.new((0.02, 0.0, 0.045))
for i in range(n):
    j = (i + 1) % n; p.face([e[i], e[j], mm[j], mm[i]], gl); p.face([mm[i], mm[j], c], gl)
p.export("terrain/decor_glue.glb", smooth=True)
mat("Paper_Newsprint", (0.86, 0.84, 0.78)); mat("Paper_Print", (0.40, 0.39, 0.37))
p = Piece(); sc = p.m("Paper_Newsprint"); pr = p.m("Paper_Print")
outline = []
for i in range(14):
    a = 2 * math.pi * i / 14; rr = rng.uniform(0.30, 0.42)
    outline.append(p.bm.verts.new((math.cos(a) * rr * 1.3, math.sin(a) * rr * 0.8, 0.004 + max(0.0, math.cos(a)) * 0.05)))
p.face(outline, sc)
for k in range(4):
    y = -0.16 + 0.1 * k; L = rng.uniform(0.25, 0.45)
    p.face([(-0.25, y, 0.009), (-0.25 + L, y, 0.009 + max(0, -0.25 + L) * 0.02), (-0.25 + L, y + 0.03, 0.009 + max(0, -0.25 + L) * 0.02), (-0.25, y + 0.03, 0.009)], pr)
p.export("terrain/decor_scrap.glb")
