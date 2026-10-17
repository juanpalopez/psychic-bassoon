
# terrain_lookdev.py - papercraft terrain look-dev for Papercraft Kingdom Defense.
# Builds the seed-1 board from maps_seed_1_7_42.json (exported from MapGen) with
# procedural, bake-friendly materials, a desk-lamp + room-fill light rig (the two
# lights Godot's Compatibility renderer has), and the game camera (35 deg vertical FOV).
# Blender: X = board columns, Y = -rows (Godot -Z), Z up. 1 unit = 1 cell = 1 m.
import bpy, bmesh, math, random, json, os
from mathutils import Vector, Matrix, Euler

HERE = "/Users/juanlopezguzman/Documents/projects/psychic-bassoon/assets-src/terrain_lookdev"
SEED = "1"
MAP = json.load(open(os.path.join(HERE, "maps_seed_1_7_42.json")))[SEED]
COLS, ROWS = MAP["cols"], MAP["rows"]
LEVEL_H = {0: 0.0, 1: 1.0, 2: 2.0}          # GDD: rise +1 m, cliffs +2 m
MAT_HALF = (COLS / 2 + 1.6, ROWS / 2 + 1.6)  # printed border round the 22x16 board
MAT_T = 0.12
rng = random.Random(7)
scn = bpy.context.scene

def cell_c(col, row):
    return Vector((col - (COLS - 1) / 2, (ROWS - 1) / 2 - row, 0.0))

# ------------------------------------------------------------------ materials
class G:
    def __init__(s, name):
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True; s.m = m; s.nt = m.node_tree; s.nt.nodes.clear(); s.L = s.nt.links
        out = s.nt.nodes.new("ShaderNodeOutputMaterial"); s.b = s.nt.nodes.new("ShaderNodeBsdfPrincipled")
        s.L.new(s.b.outputs[0], out.inputs["Surface"])
        g = s.nt.nodes.new("ShaderNodeNewGeometry"); tc = s.nt.nodes.new("ShaderNodeTexCoord")
        s.pos = g.outputs["Position"]; s.P = s.sep(s.pos); s.U = s.sep(tc.outputs["UV"]); s.Nz = s.sep(g.outputs["Normal"])[2]
    def n(s, t, **kw):
        node = s.nt.nodes.new(t)
        for k, v in kw.items(): setattr(node, k, v)
        return node
    def put(s, sock, v):
        if isinstance(v, (int, float)): sock.default_value = v
        elif isinstance(v, tuple):
            if len(sock.default_value) == 4 and len(v) == 3: v = (*v, 1.0)
            sock.default_value = v
        else: s.L.new(v, sock)
    def m_(s, op, a, b=0.0, c=0.0):
        node = s.n("ShaderNodeMath", operation=op)
        s.put(node.inputs[0], a); s.put(node.inputs[1], b); s.put(node.inputs[2], c)
        return node.outputs[0]
    def sep(s, v):
        node = s.n("ShaderNodeSeparateXYZ"); s.L.new(v, node.inputs[0]); return node.outputs
    def vec(s, x, y, z=0.0):
        node = s.n("ShaderNodeCombineXYZ")
        for i, v in enumerate((x, y, z)): s.put(node.inputs[i], v)
        return node.outputs[0]
    def mix(s, f, a, b):
        node = s.n("ShaderNodeMix", data_type='RGBA', clamp_factor=True)
        s.put([i for i in node.inputs if i.name == "Factor" and i.type == 'VALUE'][0], f)
        s.put([i for i in node.inputs if i.name == "A" and i.type == 'RGBA'][0], a)
        s.put([i for i in node.inputs if i.name == "B" and i.type == 'RGBA'][0], b)
        return [o for o in node.outputs if o.type == 'RGBA'][0]
    def mr(s, x, a0, a1, b0=0.0, b1=1.0):
        node = s.n("ShaderNodeMapRange", interpolation_type='SMOOTHSTEP', clamp=True)
        ins = [i for i in node.inputs if i.type == 'VALUE']
        for sock, v in zip(ins[:5], (x, a0, a1, b0, b1)): s.put(sock, v)
        return [o for o in node.outputs if o.type == 'VALUE'][0]
    def noise(s, vec, scale, detail=4.0, rough=0.55):
        node = s.n("ShaderNodeTexNoise"); s.put(node.inputs["Vector"], vec)
        node.inputs["Scale"].default_value = scale; node.inputs["Detail"].default_value = detail
        node.inputs["Roughness"].default_value = rough
        return node.outputs["Fac"]
    def edge(s, vec, scale):
        node = s.n("ShaderNodeTexVoronoi", feature='DISTANCE_TO_EDGE'); s.put(node.inputs["Vector"], vec)
        node.inputs["Scale"].default_value = scale; return node.outputs["Distance"]
    def white(s, w):
        node = s.n("ShaderNodeTexWhiteNoise", noise_dimensions='1D'); s.put(node.inputs["W"], w)
        return node.outputs["Value"]
    def bump(s, h, strength, dist=0.02):
        node = s.n("ShaderNodeBump"); s.put(node.inputs["Height"], h)
        node.inputs["Strength"].default_value = strength; node.inputs["Distance"].default_value = dist
        return node.outputs["Normal"]
    def set(s, name, v): s.put(s.b.inputs[name], v)
    def mul(s, a, b): return s.m_('MULTIPLY', a, b)
    def add(s, a, b): return s.m_('ADD', a, b)
    def dist_int(s, v, k=1.0):
        vk = s.mul(v, k); return s.m_('DIVIDE', s.m_('ABSOLUTE', s.m_('SUBTRACT', vk, s.m_('ROUND', vk))), k)

def mat_cutting_mat():
    g = G("PK_CuttingMat"); x, y, z = g.P[0], g.P[1], g.P[2]
    ax, ay = g.m_('ABSOLUTE', x), g.m_('ABSOLUTE', y)
    inside = g.mul(g.mr(ax, COLS / 2 - 0.02, COLS / 2 + 0.02, 1, 0), g.mr(ay, ROWS / 2 - 0.02, ROWS / 2 + 0.02, 1, 0))
    major = g.mr(g.m_('MINIMUM', g.dist_int(x), g.dist_int(y)), 0.008, 0.014, 1, 0)
    minor = g.mul(g.mr(g.m_('MINIMUM', g.dist_int(x, 2.0), g.dist_int(y, 2.0)), 0.004, 0.008, 1, 0), inside)
    frame = g.mr(g.m_('ABSOLUTE', g.m_('MAXIMUM', g.m_('SUBTRACT', ax, COLS / 2), g.m_('SUBTRACT', ay, ROWS / 2))), 0.03, 0.045, 1, 0)
    speck = g.noise(g.pos, 220.0, 2.0)
    col = g.mix(speck, (0.010, 0.068, 0.036), (0.016, 0.088, 0.048))
    col = g.mix(g.mul(minor, 0.30), col, (0.07, 0.19, 0.11))
    col = g.mix(g.mul(major, 0.75), col, (0.11, 0.28, 0.16))
    col = g.mix(frame, col, (0.42, 0.33, 0.07))
    cut1 = g.mr(g.edge(g.vec(x, g.mul(y, 0.35)), 0.55), 0.0, 0.006, 1, 0)
    cut2 = g.mr(g.edge(g.vec(g.mul(x, 0.3), y), 0.7), 0.0, 0.005, 1, 0)
    patch = g.mr(g.noise(g.mul(g.pos, 0.35), 1.0, 2.0), 0.45, 0.6, 0, 1)
    cuts = g.mul(g.m_('MAXIMUM', cut1, cut2), patch)
    col = g.mix(g.mul(cuts, 0.45), col, (0.05, 0.15, 0.09))
    side = g.mr(g.m_('ABSOLUTE', g.Nz), 0.5, 0.6, 1, 0)
    band = g.mr(z, -0.035, -0.03, 0, 1)
    sidecol = g.mix(band, (0.012, 0.012, 0.014), (0.030, 0.135, 0.078))
    col = g.mix(side, col, sidecol)
    g.set("Base Color", col)
    g.set("Roughness", g.add(0.42, g.mul(speck, 0.12)))
    g.set("Normal", g.bump(g.m_('SUBTRACT', 1.0, cuts), 0.12, 0.01))
    return g.m

def mat_tape():
    g = G("PK_MaskingTape"); u, v = g.U[0], g.U[1]
    crinkle = g.noise(g.vec(g.mul(u, 1.1), g.mul(v, 7.0)), 2.2, 6.0, 0.6)
    fine = g.noise(g.pos, 160.0, 2.0)
    col = g.mix(crinkle, (0.62, 0.47, 0.25), (0.50, 0.37, 0.18))
    x, y = g.P[0], g.P[1]
    thru = g.mr(g.m_('MINIMUM', g.dist_int(x), g.dist_int(y)), 0.008, 0.014, 1, 0)
    col = g.mix(g.mul(thru, 0.22), col, (0.30, 0.30, 0.18))
    edge = g.m_('MAXIMUM', g.mr(v, 0.0, 0.07, 1, 0), g.mr(v, 0.93, 1.0, 0, 1))
    col = g.mix(g.mul(edge, 0.55), col, (0.36, 0.26, 0.12))
    g.set("Base Color", col); g.set("Roughness", 0.52); g.set("Coat Weight", 0.15)
    g.set("Normal", g.bump(g.add(g.mul(crinkle, 0.8), g.mul(fine, 0.2)), 0.6, 0.012))
    return g.m

def mat_corrugated():
    g = G("PK_Corrugated"); u, v = g.U[0], g.U[1]; x, y = g.P[0], g.P[1]
    w = g.add(0.5, g.mul(g.m_('SINE', g.mul(u, 2 * math.pi / 0.26)), 0.30))
    flute = g.mr(g.m_('ABSOLUTE', g.m_('SUBTRACT', v, w)), 0.06, 0.09, 1, 0)
    liner = g.m_('MAXIMUM', g.mr(v, 0.11, 0.14, 1, 0), g.mr(v, 0.86, 0.89, 0, 1))
    side = g.mix(flute, (0.012, 0.007, 0.003), (0.40, 0.25, 0.11))
    side = g.mix(liner, side, (0.30, 0.18, 0.08))
    blot = g.noise(g.pos, 1.4, 3.0); fib = g.noise(g.vec(g.mul(x, 3.0), g.mul(y, 30.0)), 4.0, 8.0)
    top = g.mix(blot, (0.34, 0.20, 0.09), (0.44, 0.28, 0.13))
    top = g.mix(g.mul(fib, 0.35), top, (0.52, 0.35, 0.18))
    topm = g.mr(g.Nz, 0.5, 0.6, 0, 1)
    g.set("Base Color", g.mix(topm, side, top))
    g.set("Roughness", 0.85)
    hs = g.m_('MAXIMUM', flute, liner)
    ht = g.add(g.mul(g.m_('SINE', g.mul(u, 2 * math.pi / 0.22)), 0.25), g.mul(fib, 0.4))
    h = g.add(g.mul(topm, ht), g.mul(g.m_('SUBTRACT', 1.0, topm), hs))
    g.set("Normal", g.bump(h, 0.55, 0.02))
    return g.m

def mat_greyboard():
    g = G("PK_Greyboard"); z = g.P[2]
    k = g.m_('FLOOR', g.m_('DIVIDE', z, 0.1)); hv = g.white(k)
    lay = g.mix(hv, (0.12, 0.118, 0.11), (0.32, 0.31, 0.29))
    glue = g.mr(g.m_('FRACT', g.m_('DIVIDE', z, 0.1)), 0.02, 0.06, 1, 0)
    side = g.mix(g.mul(glue, 0.7), lay, (0.07, 0.065, 0.06))
    fl = g.mr(g.noise(g.pos, 70.0, 2.0), 0.70, 0.73, 0, 1)
    top = g.mix(g.noise(g.pos, 3.0, 3.0), (0.26, 0.25, 0.235), (0.33, 0.32, 0.30))
    topm = g.mr(g.Nz, 0.5, 0.6, 0, 1)
    col = g.mix(topm, side, top)
    col = g.mix(g.mul(fl, 0.6), col, (0.10, 0.13, 0.24))
    g.set("Base Color", col); g.set("Roughness", 0.9)
    fray = g.noise(g.pos, 22.0, 5.0)
    g.set("Normal", g.bump(g.add(g.mul(fray, 0.5), g.mul(g.m_('SUBTRACT', 1.0, topm), g.m_('SUBTRACT', 1.0, glue))), 0.3, 0.01))
    return g.m

def mat_pencil_ring():
    g = G("PK_PencilRing"); st = g.noise(g.vec(g.mul(g.U[0], 4.0), g.mul(g.U[1], 0.5)), 6.0, 4.0)
    g.set("Base Color", g.mix(st, (0.62, 0.62, 0.60), (0.88, 0.88, 0.86))); g.set("Roughness", 0.75)
    return g.m

def mat_simple(name, col, rough, metal=0.0, coat=0.0, emis=None, estr=0.0, sss=0.0):
    g = G(name); g.set("Base Color", col); g.set("Roughness", rough); g.set("Metallic", metal)
    if coat: g.set("Coat Weight", coat); g.set("Coat Roughness", 0.04)
    if emis: g.set("Emission Color", emis); g.set("Emission Strength", estr)
    if sss: g.set("Subsurface Weight", sss)
    return g.m

def mat_ink():
    g = G("PK_BlotInk")
    rip = g.noise(g.pos, 6.0, 3.0)
    g.set("Base Color", (0.030, 0.003, 0.070)); g.set("Roughness", 0.05)
    g.set("Coat Weight", 1.0); g.set("Coat Roughness", 0.02)
    try: g.set("Specular Tint", (0.75, 0.40, 1.0))
    except Exception: pass
    g.set("Normal", g.bump(rip, 0.08, 0.01))
    return g.m

def mat_wood():
    g = G("PK_DeskWood"); x, y = g.P[0], g.P[1]
    grain = g.noise(g.vec(g.mul(x, 0.04), g.mul(y, 0.9)), 1.6, 6.0, 0.5)
    rings = g.m_('FRACT', g.mul(grain, 9.0))
    col = g.mix(g.mr(rings, 0.2, 0.8, 0, 1), (0.30, 0.15, 0.06), (0.42, 0.23, 0.10))
    seam = g.mr(g.dist_int(g.m_('DIVIDE', y, 4.5)), 0.002, 0.004, 1, 0)
    col = g.mix(seam, col, (0.08, 0.04, 0.02))
    g.set("Base Color", col); g.set("Roughness", g.add(0.30, g.mul(rings, 0.15))); g.set("Coat Weight", 0.6)
    g.set("Coat Roughness", 0.12)
    g.set("Normal", g.bump(g.m_('SUBTRACT', 1.0, seam), 0.3, 0.01))
    return g.m

def mat_glass():
    return mat_simple("PK_InkBottleGlass", (0.020, 0.002, 0.045), 0.04, coat=1.0)

MATS = {
    "mat": mat_cutting_mat(), "tape": mat_tape(), "card": mat_corrugated(), "grey": mat_greyboard(),
    "ring": mat_pencil_ring(), "ink": mat_ink(), "wood": mat_wood(), "glass": mat_glass(),
    "heart": mat_simple("PK_HeartPaper", (0.42, 0.006, 0.03), 0.45, emis=(1.0, 0.03, 0.10), estr=0.7, sss=0.25),
    "cardstock": mat_simple("PK_Cardstock", (0.62, 0.55, 0.43), 0.8),
    "pencil": mat_simple("PK_PencilPaint", (0.78, 0.42, 0.02), 0.35, coat=0.5),
    "pwood": mat_simple("PK_PencilWood", (0.66, 0.42, 0.22), 0.8),
    "graphite": mat_simple("PK_Graphite", (0.03, 0.03, 0.035), 0.35, metal=0.3),
    "ferrule": mat_simple("PK_Ferrule", (0.80, 0.66, 0.36), 0.25, metal=1.0),
    "rubber": mat_simple("PK_Rubber", (0.80, 0.30, 0.34), 0.7),
    "cap": mat_simple("PK_BottleCap", (0.02, 0.02, 0.02), 0.4),
}

# ------------------------------------------------------------------ geometry helpers
COLL = {}
def coll(name):
    if name not in COLL:
        c = bpy.data.collections.get(name) or bpy.data.collections.new(name)
        if c.name not in scn.collection.children: scn.collection.children.link(c)
        for o in list(c.objects): bpy.data.objects.remove(o, do_unlink=True)
        COLL[name] = c
    return COLL[name]

def emit(name, bm, mats, cname, smooth=False):
    for f in bm.faces: f.smooth = smooth
    me = bpy.data.meshes.get(name)
    if me: bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for k in mats: me.materials.append(MATS[k])
    o = bpy.data.objects.new(name, me); coll(cname).objects.link(o); return o

def set_uv(bm, faces, mode, zb=0.0, h=1.0):
    uv = bm.loops.layers.uv.verify()
    for f in faces:
        n = f.normal
        for lp in f.loops:
            co = lp.vert.co
            if abs(n.z) > 0.6: lp[uv].uv = (co.x, co.y)
            else:
                t = Vector((-n.y, n.x, 0.0))
                t = t.normalized() if t.length > 1e-6 else Vector((1, 0, 0))
                along = co.x * t.x + co.y * t.y
                lp[uv].uv = (along, (co.z - zb) / h if mode == "layer" else co.z)

def box(bm, centre, size, yaw=0.0, bevel=0.0, mi=0, uvmode="z", zb=0.0, h=1.0):
    # built in its own bmesh (bevel replaces the corner verts), then appended to bm
    tmp = bmesh.new()
    m = Matrix.Translation(centre) @ Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Diagonal(Vector((*size, 1.0)))
    bmesh.ops.create_cube(tmp, size=1.0, matrix=m)
    if bevel > 0:
        bmesh.ops.bevel(tmp, geom=tmp.verts[:] + tmp.edges[:], offset=bevel, segments=1, affect='EDGES', clamp_overlap=True)
    tmp.normal_update()
    for f in tmp.faces: f.material_index = mi
    set_uv(tmp, tmp.faces, uvmode, zb, h)
    me = bpy.data.meshes.new("_tmpbox"); tmp.to_mesh(me); tmp.free()
    bm.from_mesh(me); bpy.data.meshes.remove(me)

# ------------------------------------------------------------------ desk + mat + print
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=40.0, matrix=Matrix.Translation((0, 0, -MAT_T)))
emit("Desk", bm, ["wood"], "Diorama")
bm = bmesh.new()
box(bm, Vector((0, 0, -MAT_T / 2)), (MAT_HALF[0] * 2, MAT_HALF[1] * 2, MAT_T), bevel=0.03)
emit("CuttingMat", bm, ["mat"], "Board")
txtmat = bpy.data.materials.get("PK_MatPrint") or bpy.data.materials.new("PK_MatPrint")
txtmat.diffuse_color = (0.26, 0.52, 0.33, 1)
txtmat.use_nodes = True
txtmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.26, 0.52, 0.33, 1)
txtmat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.45
def label(body, x, y, size=0.42, rot=0.0):
    cu = bpy.data.curves.new("lbl_" + body, 'FONT'); cu.body = body; cu.size = size
    cu.align_x = 'CENTER'; cu.align_y = 'CENTER'; cu.materials.append(txtmat)
    o = bpy.data.objects.new("lbl_" + body, cu); o.location = (x, y, 0.002); o.rotation_euler = (0, 0, rot)
    coll("Board").objects.link(o)
for c in range(COLS):
    label(str(c + 1), c - (COLS - 1) / 2, ROWS / 2 + 0.55)
for r in range(ROWS):
    label("ABCDEFGHIJKLMNOP"[r], -COLS / 2 - 0.55, (ROWS - 1) / 2 - r)

# ------------------------------------------------------------------ tape lane (path runs)
path = [tuple(p) for p in MAP["path"]]
runs = []; s = 0
for i in range(1, len(path)):
    d0 = (path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1])
    if i + 1 < len(path):
        d1 = (path[i + 1][0] - path[i][0], path[i + 1][1] - path[i][1])
        if d1 != d0: runs.append((s, i)); s = i
runs.append((s, len(path) - 1))
bm = bmesh.new(); uvl = bm.loops.layers.uv.verify()
def tape(p0, p1, width, z, first=False, last=False):
    d = (p1 - p0); L = d.length; d.normalize(); nrm = Vector((-d.y, d.x, 0))
    a0 = rng.uniform(-0.012, 0.012)
    steps = max(2, int(L / 0.5)); rows = []
    for k in range(steps + 1):
        t = k / steps; c = p0 + d * (L * t) + nrm * (a0 * (t - 0.5) * L * 0.2)
        wob = lambda: rng.uniform(-0.008, 0.008)
        rows.append((bm.verts.new(c + nrm * (width / 2 + wob()) + Vector((0, 0, z))),
                     bm.verts.new(c - nrm * (width / 2 + wob()) + Vector((0, 0, z))), L * t))
    for k in range(steps):
        (l0, r0, u0), (l1, r1, u1) = rows[k], rows[k + 1]
        f = bm.faces.new((l0, r0, r1, l1))
        for lp, uvv in zip(f.loops, ((u0, 1), (u0, 0), (u1, 0), (u1, 1))): lp[uvl].uv = uvv
    for end, sgn in ((0, -1), (steps, 1)):
        l, r, u = rows[end]; teeth = []
        for j in range(1, 6):
            t = j / 6; c = l.co.lerp(r.co, t) + d * sgn * rng.uniform(0.0, 0.07)
            teeth.append((bm.verts.new(c), u + sgn * 0.03, 1 - t))
        ring = [l] + [tv for tv, _, _ in teeth] + [r]
        uvs = [(u, 1)] + [(uu, vv) for _, uu, vv in teeth] + [(u, 0)]
        if sgn > 0: ring, uvs = ring[::-1], uvs[::-1]
        f = bm.faces.new(ring)
        for lp, uvv in zip(f.loops, uvs): lp[uvl].uv = uvv
for k, (a, b) in enumerate(runs):
    p0 = cell_c(*path[a]); p1 = cell_c(*path[b]); d = (p1 - p0).normalized()
    p0 = p0 - d * (1.4 if k == 0 else 0.46); p1 = p1 + d * (0.62 if k == len(runs) - 1 else 0.46)
    tape(p0, p1, 0.84, 0.004 + 0.0014 * (k % 3))
emit("TapeLane", bm, ["tape"], "Board")

# ------------------------------------------------------------------ sockets
bm_card = bmesh.new(); bm_grey = bmesh.new(); bm_ring = bmesh.new(); ruv = bm_ring.loops.layers.uv.verify()
def ring(cx, cy, z, r_out=0.80, w=0.065, n=48):
    outer = []; inner = []
    for i in range(n):
        a = 2 * math.pi * i / n; ca, sa = math.cos(a), math.sin(a)
        outer.append(bm_ring.verts.new((cx + ca * r_out, cy + sa * r_out, z)))
        inner.append(bm_ring.verts.new((cx + ca * (r_out - w), cy + sa * (r_out - w), z)))
    for i in range(n):
        j = (i + 1) % n; f = bm_ring.faces.new((inner[i], inner[j], outer[j], outer[i]))
        for lp, uvv in zip(f.loops, ((i / n * 5, 0), ((i + 1) / n * 5, 0), ((i + 1) / n * 5, 1), (i / n * 5, 1))): lp[ruv].uv = uvv
    for a in (0, 0.5 * math.pi, math.pi, 1.5 * math.pi):
        ca, sa = math.cos(a), math.sin(a); tx, ty = -sa, ca
        p = [Vector((cx + ca * rr + tx * ww, cy + sa * rr + ty * ww, z)) for rr, ww in
             ((r_out - w, -0.025), (r_out - w, 0.025), (r_out - w - 0.16, 0.02), (r_out - w - 0.16, -0.02))]
        vv = [bm_ring.verts.new(q) for q in p]; f = bm_ring.faces.new(vv)
        for lp in f.loops: lp[ruv].uv = (0.5, 0.5)
for (c, r, lv) in MAP["sockets"]:
    cx, cy = c - (COLS - 1) / 2 + 0.5, (ROWS - 1) / 2 - r - 0.5
    H = LEVEL_H[lv]
    if lv == 1:
        for k in range(5):
            jx, jy = rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03)
            box(bm_card, Vector((cx + jx, cy + jy, 0.1 + 0.2 * k)), (1.92, 1.92, 0.2), yaw=math.radians(rng.uniform(-1.2, 1.2)),
                bevel=0.012, uvmode="layer", zb=0.2 * k, h=0.2)
    elif lv == 2:
        box(bm_grey, Vector((cx, cy, 0.55)), (1.95, 1.95, 1.1), yaw=math.radians(rng.uniform(-1, 1)), bevel=0.015)
        box(bm_grey, Vector((cx + rng.uniform(-0.04, 0.04), cy + rng.uniform(-0.04, 0.04), 1.55)), (1.66, 1.66, 0.9),
            yaw=math.radians(rng.uniform(-2.5, 2.5)), bevel=0.015)
    ring(cx, cy, H + (0.0025 if lv == 0 else 0.002))
emit("Plinths_L1_Corrugated", bm_card, ["card"], "Board")
emit("Plinths_L2_Greyboard", bm_grey, ["grey"], "Board")
emit("SocketRings", bm_ring, ["ring"], "Board")

# ------------------------------------------------------------------ heartstone
hc, hr, hw, hh = MAP["heart"]
hx, hy = hc - (COLS - 1) / 2 + (hw - 1) / 2, (ROWS - 1) / 2 - hr - (hh - 1) / 2
bm = bmesh.new()
n = 16; top = []; bot = []
for i in range(n):
    a = 2 * math.pi * i / n; rr = 0.92 if i % 2 == 0 else 0.84
    bot.append(bm.verts.new((hx + math.cos(a) * rr, hy + math.sin(a) * rr, 0.0)))
    top.append(bm.verts.new((hx + math.cos(a) * rr * 0.9, hy + math.sin(a) * rr * 0.9, 0.12 + (0.025 if i % 2 else 0.0))))
for i in range(n):
    j = (i + 1) % n; bm.faces.new((bot[i], bot[j], top[j], top[i]))
cv = bm.verts.new((hx, hy, 0.16))
for i in range(n): bm.faces.new((top[i], top[(i + 1) % n], cv))
cone_b = [bm.verts.new((hx + math.cos(2 * math.pi * i / 6) * 0.32, hy + math.sin(2 * math.pi * i / 6) * 0.32, 0.12)) for i in range(6)]
cone_t = [bm.verts.new((hx + math.cos(2 * math.pi * i / 6) * 0.12, hy + math.sin(2 * math.pi * i / 6) * 0.12, 0.48)) for i in range(6)]
for i in range(6):
    j = (i + 1) % 6; bm.faces.new((cone_b[i], cone_b[j], cone_t[j], cone_t[i]))
bm.faces.new(cone_t)
for f in bm.faces: f.material_index = 0
prof = [(0, 0), (0.55, 0.55), (0.85, 1.0), (0.80, 1.35), (0.55, 1.55), (0.25, 1.45), (0, 1.25), (-0.25, 1.45), (-0.55, 1.55), (-0.80, 1.35), (-0.85, 1.0), (-0.55, 0.55)]
ringv = [bm.verts.new((hx + px * 1.05, hy, 0.42 + pz * 1.05)) for px, pz in prof]
fr = bm.verts.new((hx, hy - 0.42, 0.42 + 0.95 * 1.05)); bk = bm.verts.new((hx, hy + 0.42, 0.42 + 0.95 * 1.05))
# lean the heart back so its face reads from the high game camera (65 deg zoomed out)
lean = Matrix.Translation((hx, hy, 0.45)) @ Matrix.Rotation(math.radians(-42), 4, 'X') @ Matrix.Translation((-hx, -hy, -0.45))
for v in ringv + [fr, bk]: v.co = lean @ v.co
for i in range(len(ringv)):
    j = (i + 1) % len(ringv)
    bm.faces.new((ringv[i], ringv[j], fr)).material_index = 1
    bm.faces.new((ringv[j], ringv[i], bk)).material_index = 1
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
emit("Heartstone", bm, ["cardstock", "heart"], "Board")
hl = bpy.data.lights.new("HeartGlow", 'POINT'); hl.energy = 35; hl.color = (1.0, 0.12, 0.20); hl.shadow_soft_size = 0.3
ho = bpy.data.objects.new("HeartGlow", hl); ho.location = (hx, hy - 1.3, 2.0); coll("Lights").objects.link(ho)

# ------------------------------------------------------------------ the Blot: spilled ink bottle at the spawn
sx, sy = cell_c(*path[0]).x, cell_c(*path[0]).y
bm = bmesh.new()
def blob(cx, cy, rx, ry, z, th, rot=0.0, n=32):
    harm = [(rng.uniform(0.05, 0.16), rng.randint(2, 5), rng.uniform(0, 6.28)) for _ in range(4)]
    edge = []; mid = []
    for i in range(n):
        a = 2 * math.pi * i / n; k = 1.0 + sum(h * math.sin(m * a + p) for h, m, p in harm)
        ex, ey = math.cos(a) * rx * k, math.sin(a) * ry * k
        ex, ey = ex * math.cos(rot) - ey * math.sin(rot), ex * math.sin(rot) + ey * math.cos(rot)
        edge.append(bm.verts.new((cx + ex, cy + ey, z)))
        mid.append(bm.verts.new((cx + ex * 0.88, cy + ey * 0.88, z + th)))
    c = bm.verts.new((cx, cy, z + th * 1.15))
    for i in range(n):
        j = (i + 1) % n; bm.faces.new((edge[i], edge[j], mid[j], mid[i])); bm.faces.new((mid[i], mid[j], c))
blob(sx - 0.9, sy + 0.15, 1.15, 0.62, 0.008, 0.02, rot=0.15)
blob(sx + 0.2, sy - 0.05, 0.62, 0.40, 0.010, 0.018, rot=-0.2)
blob(sx - 1.75, sy + 0.9, 0.55, 0.42, 0.006, 0.02, rot=0.6)
emit("BlotInk", bm, ["ink"], "Board", smooth=True)
bm = bmesh.new()
bx, by = sx - 2.6, sy + 1.55; axis = Vector((0.82, -0.57, 0)).normalized()
m = Matrix.Translation((bx, by, 0.56)) @ axis.to_track_quat('Z', 'Y').to_matrix().to_4x4()
prof = [(0.0, -0.75), (0.55, -0.75), (0.56, 0.45), (0.25, 0.70), (0.23, 0.95), (0.28, 1.0), (0.0, 1.0)]
segs = 16; rings_ = []
for pr, pz in prof:
    rings_.append([bm.verts.new(m @ Vector((math.cos(2 * math.pi * i / segs) * pr, math.sin(2 * math.pi * i / segs) * pr, pz))) for i in range(segs)])
for a, b in zip(rings_, rings_[1:]):
    for i in range(segs):
        j = (i + 1) % segs; bm.faces.new((a[i], a[j], b[j], b[i]))
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
emit("InkBottle", bm, ["glass"], "Diorama", smooth=True)
bm = bmesh.new()
lab = [m @ Vector((math.cos(2 * math.pi * i / segs) * 0.575, math.sin(2 * math.pi * i / segs) * 0.575, zz)) for zz in (-0.45, 0.25) for i in range(segs)]
lv = [bm.verts.new(q) for q in lab]
for i in range(segs):
    j = (i + 1) % segs; bm.faces.new((lv[i], lv[j], lv[segs + j], lv[segs + i]))
emit("InkBottleLabel", bm, ["cardstock"], "Diorama", smooth=True)
bm = bmesh.new()
mc = Matrix.Translation((bx - 0.2, by + 1.3, 0.32)) @ Matrix.Rotation(math.radians(90), 4, 'X')
bmesh.ops.create_cone(bm, segments=20, radius1=0.30, radius2=0.30, depth=0.62, cap_ends=True, matrix=mc)
emit("InkBottleCap", bm, ["cap"], "Diorama", smooth=True)

# ------------------------------------------------------------------ desk props
bm = bmesh.new(); py = -MAT_HALF[1] - 1.1; px0 = 3.0
mp = Matrix.Translation((px0 + 2.2, py, 0.2 - MAT_T)) @ Matrix.Rotation(math.radians(90), 4, 'Y') @ Matrix.Rotation(math.radians(30), 4, 'Z')
r1 = bmesh.ops.create_cone(bm, segments=6, radius1=0.2, radius2=0.2, depth=4.4, cap_ends=True, matrix=mp)
for f in {f for v in r1["verts"] for f in v.link_faces}: f.material_index = 0
mt = Matrix.Translation((px0 + 4.75, py, 0.2 - MAT_T)) @ Matrix.Rotation(math.radians(90), 4, 'Y')
r2 = bmesh.ops.create_cone(bm, segments=6, radius1=0.2, radius2=0.02, depth=0.7, cap_ends=True, matrix=mt)
for f in {f for v in r2["verts"] for f in v.link_faces}: f.material_index = 1
mf = Matrix.Translation((px0 - 0.15, py, 0.2 - MAT_T)) @ Matrix.Rotation(math.radians(90), 4, 'Y')
r3 = bmesh.ops.create_cone(bm, segments=12, radius1=0.21, radius2=0.21, depth=0.3, cap_ends=True, matrix=mf)
for f in {f for v in r3["verts"] for f in v.link_faces}: f.material_index = 2
me_ = Matrix.Translation((px0 - 0.5, py, 0.2 - MAT_T)) @ Matrix.Rotation(math.radians(90), 4, 'Y')
r4 = bmesh.ops.create_cone(bm, segments=12, radius1=0.2, radius2=0.2, depth=0.42, cap_ends=True, matrix=me_)
for f in {f for v in r4["verts"] for f in v.link_faces}: f.material_index = 3
box(bm, Vector((12.5, py + 0.2, 0.18 - MAT_T)), (1.3, 0.62, 0.36), yaw=math.radians(18), bevel=0.06, mi=3)
emit("DeskProps", bm, ["pencil", "pwood", "ferrule", "rubber"], "Diorama")

# ------------------------------------------------------------------ lights (Godot parity: one directional + ambient)
L = Vector((-0.62, 0.38, 0.66)).normalized()
sun = bpy.data.lights.new("DeskLamp_Key", 'SUN'); sun.energy = 5.2; sun.color = (1.0, 0.82, 0.62); sun.angle = math.radians(2.0)
so = bpy.data.objects.new("DeskLamp_Key", sun); so.rotation_euler = (-L).to_track_quat('-Z', 'Y').to_euler()
coll("Lights").objects.link(so)
w = scn.world or bpy.data.worlds.new("Room"); scn.world = w; w.use_nodes = True
bgn = w.node_tree.nodes.get("Background") or w.node_tree.nodes.new("ShaderNodeBackground")
bgn.inputs["Color"].default_value = (0.55, 0.63, 0.80, 1); bgn.inputs["Strength"].default_value = 0.38
wo = w.node_tree.nodes.get("World Output") or w.node_tree.nodes.new("ShaderNodeOutputWorld")
w.node_tree.links.new(bgn.outputs[0], wo.inputs["Surface"])

# ------------------------------------------------------------------ cameras (game rig: 35 deg vertical FOV)
def camera(name, target, pitch_deg, dist, yaw_deg=0.0):
    cc = coll("Cameras")   # clears last run's cameras first, so fetch after
    cd = bpy.data.cameras.get(name) or bpy.data.cameras.new(name)
    cd.sensor_fit = 'VERTICAL'; cd.angle_y = math.radians(35.0); cd.clip_end = 300
    o = bpy.data.objects.get(name) or bpy.data.objects.new(name, cd)
    if o.name not in cc.objects: cc.objects.link(o)
    p, yw = math.radians(pitch_deg), math.radians(yaw_deg)
    off = Vector((math.sin(yw) * math.cos(p), -math.cos(yw) * math.cos(p), math.sin(p))) * dist
    o.location = Vector(target) + off
    o.rotation_euler = (Vector(target) - o.location).to_track_quat('-Z', 'Y').to_euler()
    return o
cam_wide = camera("Cam_Wide_65", (0, 0.4, 0.4), 65.0, 30.0)
l2 = [s for s in MAP["sockets"] if s[2] == 2][0]
tx, ty = l2[0] - (COLS - 1) / 2 + 0.5, (ROWS - 1) / 2 - l2[1] - 0.5
cam_close = camera("Cam_Close_38", (tx + 1.0, ty - 0.5, 0.6), 38.0, 12.5, yaw_deg=-12.0)
cam_heart = camera("Cam_Heart_45", (hx - 1.5, hy + 0.2, 0.7), 45.0, 10.0, yaw_deg=-20.0)
scn.camera = cam_wide

# ------------------------------------------------------------------ render settings
for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
    try: scn.render.engine = eng; break
    except Exception: pass
scn.render.resolution_x, scn.render.resolution_y, scn.render.resolution_percentage = 1280, 720, 100
try: scn.eevee.taa_render_samples = 64
except Exception: pass
try: scn.view_settings.view_transform = 'AgX'
except Exception: pass

for attr, val in (("use_raytracing", True), ("use_shadows", True), ("shadow_ray_count", 2), ("shadow_step_count", 8)):
    try: setattr(scn.eevee, attr, val)
    except Exception: pass
