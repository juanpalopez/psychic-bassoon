
# towers_lib.py - mesh helpers and look-dev materials for the hi-def papercraft towers.
# Exec'd by towers_hd.py inside Blender. Every part is built as one bmesh with a
# "Col" colour layer (linear RGB, alpha = glow, as render/paper/paper_vc.gdshader reads it)
# and material names that pick a Godot look (PK_*). Units are metres, Z up, the tower
# faces Blender -Y (glTF +Z).
import bpy, bmesh, math
from mathutils import Vector, Matrix

TAU = math.tau


def lin(c, a=0.0):
    """sRGB 0-1 (or hex string) to a linear RGBA tuple; a is the glow amount."""
    if isinstance(c, str):
        c = c.lstrip("#"); c = tuple(int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    f = lambda x: ((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92
    return (f(c[0]), f(c[1]), f(c[2]), a)


def shade(c, k):
    """Darken (k<1) or lighten (k>1) a linear colour, keeping glow."""
    return (min(c[0] * k, 1.0), min(c[1] * k, 1.0), min(c[2] * k, 1.0), c[3])


def mixc(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(4))


class Part:
    """One mesh object in the making: faces with per-corner colours and a material each."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.uvl = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []

    def mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def face(self, cos, col, mat="PK_PaperVC", uvs=None, smooth=False):
        vs = [self.bm.verts.new(Vector(c)) for c in cos]
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.material_index = self.mi(mat)
        f.smooth = smooth
        if uvs is None:
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            pick = {0: (1, 2), 1: (0, 2), 2: (0, 1)}[ax]
            uvs = [(c[pick[0]], c[pick[1]]) for c in cos]
        for k, lp in enumerate(f.loops):
            lp[self.col] = col[k] if isinstance(col, list) else col
            lp[self.uvl].uv = uvs[k]
        return f

    # ---------- primitives ----------
    def lathe(self, prof, segs=24, col=(0.8, 0.8, 0.8, 0.0), mat="PK_PaperVC", M=None, a0=0.0,
              arc=TAU, colf=None, smooth=True, uv_scale=1.0):
        """Revolve a profile [(r, z), ...] about Z. Profile going up faces outwards.
        colf(j, i, ang) -> colour of the band j (between profile points j and j+1), slice i."""
        M = M or Matrix()
        closed = abs(arc - TAU) < 1e-6
        n = segs if closed else segs + 1
        rings = []
        for (r, z) in prof:
            ring = []
            for i in range(n):
                a = a0 + arc * i / segs
                ring.append(M @ Vector((r * math.cos(a), r * math.sin(a), z)))
            rings.append(ring)
        vv = [0.0]
        for j in range(1, len(prof)):
            vv.append(vv[-1] + math.hypot(prof[j][0] - prof[j - 1][0], prof[j][1] - prof[j - 1][1]))
        for j in range(len(prof) - 1):
            for i in range(segs):
                i2 = (i + 1) % n if closed else i + 1
                c = colf(j, i, a0 + arc * (i + 0.5) / segs) if colf else col
                u0, u1 = i / segs * uv_scale * 4, (i + 1) / segs * uv_scale * 4
                q = [rings[j][i], rings[j][i2], rings[j + 1][i2], rings[j + 1][i]]
                uv = [(u0, vv[j]), (u1, vv[j]), (u1, vv[j + 1]), (u0, vv[j + 1])]
                if prof[j][0] < 1e-7:
                    q = [q[0], q[2], q[3]]; uv = [uv[0], uv[2], uv[3]]
                elif prof[j + 1][0] < 1e-7:
                    q = [q[0], q[1], q[2]]; uv = uv[:3]
                self.face(q, c, mat, uv, smooth)
        return self

    def disc(self, r, z, segs=24, col=None, mat="PK_PaperVC", up=True, M=None, r_in=0.0):
        """A flat disc (or ring when r_in > 0) facing up (or down)."""
        prof = [(r_in, z), (r, z)] if not up else [(r, z), (r_in, z)]
        return self.lathe(prof, segs, col, mat, M, smooth=False)

    def slab(self, poly, t, col, edge=None, mat="PK_PaperVC", M=None, edge_mat=None, both=True):
        """Extrude a CCW 2D outline [(x, y)] by thickness t along local +Z, placed by M."""
        M = M or Matrix()
        edge = edge or shade(col, 0.82)
        bot = [M @ Vector((x, y, 0.0)) for x, y in poly]
        top = [M @ Vector((x, y, t)) for x, y in poly]
        self.face(top, col, mat, [(x, y) for x, y in poly])
        if both:
            self.face(list(reversed(bot)), shade(col, 0.9), mat, [(x, y) for x, y in reversed(poly)])
        k = len(poly)
        run = 0.0
        for i in range(k):
            j = (i + 1) % k
            L = (Vector(poly[j]) - Vector(poly[i])).length
            self.face([bot[i], bot[j], top[j], top[i]], edge, edge_mat or mat,
                      [(run, 0), (run + L, 0), (run + L, t), (run, t)])
            run += L
        return self

    def box(self, lo, hi, col, edge=None, mat="PK_PaperVC", M=None, colf=None):
        """Axis box in local space (placed by M); colf(normal) -> colour overrides per side."""
        (x0, y0, z0), (x1, y1, z1) = lo, hi
        M = M or Matrix()
        P = lambda x, y, z: M @ Vector((x, y, z))
        sides = [
            ((0, 0, 1), [P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)]),
            ((0, 0, -1), [P(x0, y1, z0), P(x1, y1, z0), P(x1, y0, z0), P(x0, y0, z0)]),
            ((0, -1, 0), [P(x0, y0, z0), P(x1, y0, z0), P(x1, y0, z1), P(x0, y0, z1)]),
            ((0, 1, 0), [P(x1, y1, z0), P(x0, y1, z0), P(x0, y1, z1), P(x1, y1, z1)]),
            ((1, 0, 0), [P(x1, y0, z0), P(x1, y1, z0), P(x1, y1, z1), P(x1, y0, z1)]),
            ((-1, 0, 0), [P(x0, y1, z0), P(x0, y0, z0), P(x0, y0, z1), P(x0, y1, z1)]),
        ]
        for n, q in sides:
            c = colf(n) if colf else (col if n[2] != 0 or edge is None else edge)
            self.face(q, c, mat)
        return self

    def tube(self, pts, radius, segs=8, col=None, mat="PK_PaperVC", caps=True, colf=None, smooth=True):
        """A tube along points; radius may be a number or a list per point."""
        pts = [Vector(p) for p in pts]
        rads = radius if isinstance(radius, (list, tuple)) else [radius] * len(pts)
        tangents = []
        for k in range(len(pts)):
            a = pts[max(k - 1, 0)]; b = pts[min(k + 1, len(pts) - 1)]
            tangents.append((b - a).normalized())
        ref = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
        nrm = tangents[0].cross(ref).normalized()
        rings = []
        for k, p in enumerate(pts):
            t = tangents[k]
            nrm = (nrm - t * nrm.dot(t)).normalized()
            bi = t.cross(nrm)
            rings.append([p + (nrm * math.cos(TAU * i / segs) + bi * math.sin(TAU * i / segs)) * rads[k]
                          for i in range(segs)])
        for k in range(len(pts) - 1):
            for i in range(segs):
                i2 = (i + 1) % segs
                c = colf(k, i) if colf else col
                self.face([rings[k][i], rings[k][i2], rings[k + 1][i2], rings[k + 1][i]], c, mat,
                          [(i / segs, k), ((i + 1) / segs, k), ((i + 1) / segs, k + 1), (i / segs, k + 1)], smooth)
        if caps:
            if rads[0] > 1e-6:
                self.face(list(reversed(rings[0])), col, mat)
            if rads[-1] > 1e-6:
                self.face(rings[-1], col, mat)
        return self

    def sphere(self, c, r, segs=16, rings=10, col=None, mat="PK_PaperVC", sx=1.0, sy=1.0, sz=1.0, colf=None):
        prof = [(math.sin(math.pi * k / rings), -math.cos(math.pi * k / rings)) for k in range(rings + 1)]
        prof[0] = (0.0, -1.0); prof[-1] = (0.0, 1.0)
        M = Matrix.Translation(Vector(c)) @ Matrix.Diagonal((r * sx, r * sy, r * sz, 1.0))
        return self.lathe(prof, segs, col, mat, M, colf=colf)

    def crumple(self, c, r, col, seed=0, segs=7, rings=5, mat="PK_PaperVC"):
        """A crumpled paper ball: a low sphere with hashed dents (faceted, not smooth)."""
        start = len(self.bm.verts)
        prof = [(math.sin(math.pi * k / rings), -math.cos(math.pi * k / rings)) for k in range(rings + 1)]
        prof[0] = (0.0, -1.0); prof[-1] = (0.0, 1.0)
        M = Matrix.Translation(Vector(c)) @ Matrix.Diagonal((r, r, r * 0.92, 1.0))
        self.lathe(prof, segs, col, mat, M, smooth=False)
        self.bm.verts.ensure_lookup_table()
        cv = Vector(c)
        for k in range(start, len(self.bm.verts)):
            v = self.bm.verts[k]
            h = hash01(int(v.co.x * 997), int(v.co.y * 991), int(v.co.z * 983), seed)
            v.co = cv + (v.co - cv) * (0.78 + 0.34 * h)
        return self

    # ---------- finish ----------
    def build(self, coll, loc=(0, 0, 0), parent=None):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
        me = bpy.data.meshes.get(self.name)
        if me:
            bpy.data.meshes.remove(me)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me); bm.free()
        for k in self.mats:
            m = bpy.data.materials.get(k) or bpy.data.materials.new(k)
            me.materials.append(m)
        if me.color_attributes:
            me.color_attributes.active_color = me.color_attributes[0]
            me.color_attributes.render_color_index = 0
        old = bpy.data.objects.get(self.name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        o = bpy.data.objects.new(self.name, me)
        coll.objects.link(o)
        if parent is not None:
            o.parent = parent
        o.location = loc
        return o


def hash01(a, b, c, salt):
    h = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791) ^ (salt * 2654435761)
    h &= 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h ^= h >> 16
    return (h & 0xFFFFFF) / 16777216.0


def circle(r, n, a0=0.0, sx=1.0, sy=1.0):
    return [(r * sx * math.cos(a0 + TAU * i / n), r * sy * math.sin(a0 + TAU * i / n)) for i in range(n)]


def frame(origin, x_axis, y_axis):
    """A matrix whose local X, Y map to the given axes (Z = X cross Y) at origin."""
    x = Vector(x_axis).normalized(); y = Vector(y_axis)
    y = (y - x * y.dot(x)).normalized(); z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(origin)
    return m


# ---------- look-dev materials (Godot gets its own shaders by name) ----------
def _nodes(m):
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], out.inputs[0])
    return nt, b


def _attr(nt):
    a = nt.nodes.new("ShaderNodeAttribute"); a.attribute_name = "Col"; a.attribute_type = "GEOMETRY"
    return a


def _fibre(nt, scale=60.0, detail=6.0):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale; nz.inputs["Detail"].default_value = detail
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    return nz


def make_materials():
    # paper with its colour in the vertex colours, fibre grain, alpha = glow
    m = bpy.data.materials.get("PK_PaperVC") or bpy.data.materials.new("PK_PaperVC")
    nt, b = _nodes(m)
    a = _attr(nt); nz = _fibre(nt, 80.0)
    mul = nt.nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 0.22
    nt.links.new(a.outputs["Color"], mul.inputs[6]); nt.links.new(nz.outputs["Fac"], mul.inputs[7])
    nt.links.new(mul.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.86
    b.inputs["Sheen Weight"].default_value = 0.25
    b.inputs["Subsurface Weight"].default_value = 0.06
    b.inputs["Subsurface Radius"].default_value = (0.02, 0.012, 0.008)
    em = nt.nodes.new("ShaderNodeVectorMath"); em.operation = "SCALE"
    nt.links.new(a.outputs["Color"], em.inputs[0]); nt.links.new(a.outputs["Alpha"], em.inputs["Scale"])
    nt.links.new(em.outputs[0], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 2.5
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.08
    bump.inputs["Distance"].default_value = 0.002
    nt.links.new(nz.outputs["Fac"], bump.inputs["Height"]); nt.links.new(bump.outputs[0], b.inputs["Normal"])
    m.diffuse_color = (0.8, 0.8, 0.8, 1)

    # found wood (spool, toothpicks, matchsticks, lolly sticks): vertex colour x grain along Z
    m = bpy.data.materials.get("PK_WoodVC") or bpy.data.materials.new("PK_WoodVC")
    nt, b = _nodes(m)
    a = _attr(nt)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave"); wave.wave_type = "RINGS"
    wave.inputs["Scale"].default_value = 14.0; wave.inputs["Distortion"].default_value = 6.0
    wave.inputs["Detail"].default_value = 3.0
    mp = nt.nodes.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1.0, 1.0, 0.08)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"]); nt.links.new(mp.outputs[0], wave.inputs["Vector"])
    mul = nt.nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 0.28
    nt.links.new(a.outputs["Color"], mul.inputs[6]); nt.links.new(wave.outputs["Fac"], mul.inputs[7])
    nt.links.new(mul.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.6; b.inputs["Coat Weight"].default_value = 0.15
    m.diffuse_color = (0.7, 0.55, 0.38, 1)

    # found metal (thimble, paper clip, pins, bottle cap): tint from vertex colour,
    # vertex alpha = thimble dimples
    m = bpy.data.materials.get("PK_MetalVC") or bpy.data.materials.new("PK_MetalVC")
    nt, b = _nodes(m)
    a = _attr(nt)
    nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Metallic"].default_value = 1.0; b.inputs["Roughness"].default_value = 0.36
    b.inputs["Anisotropic"].default_value = 0.3
    tc = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi"); vor.feature = "F1"; vor.distance = "EUCLIDEAN"
    vor.inputs["Scale"].default_value = 30.0; vor.inputs["Randomness"].default_value = 0.0
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    sm = nt.nodes.new("ShaderNodeMath")
    try:
        sm.operation = "SMOOTH_MIN"
    except Exception:
        pass
    sm.operation = "LESS_THAN"
    sm.inputs[1].default_value = 0.32
    nt.links.new(vor.outputs["Distance"], sm.inputs[0])
    dm = nt.nodes.new("ShaderNodeMath"); dm.operation = "MULTIPLY"
    nt.links.new(sm.outputs[0], dm.inputs[0]); nt.links.new(a.outputs["Alpha"], dm.inputs[1])
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.9
    bump.inputs["Distance"].default_value = 0.02; bump.invert = True
    nt.links.new(dm.outputs[0], bump.inputs["Height"]); nt.links.new(bump.outputs[0], b.inputs["Normal"])
    # the dimples also read as darker dots, whatever the light
    dk = nt.nodes.new("ShaderNodeMapRange")
    dk.inputs["To Min"].default_value = 1.0; dk.inputs["To Max"].default_value = 0.55
    nt.links.new(dm.outputs[0], dk.inputs["Value"])
    sc = nt.nodes.new("ShaderNodeVectorMath"); sc.operation = "SCALE"
    nt.links.new(a.outputs["Color"], sc.inputs[0]); nt.links.new(dk.outputs[0], sc.inputs["Scale"])
    nt.links.new(sc.outputs[0], b.inputs["Base Color"])
    m.diffuse_color = (0.7, 0.72, 0.75, 1)

    # glass marble shell: tinted, mostly see-through, glossy (Godot: a transparent look)
    m = bpy.data.materials.get("PK_Glass") or bpy.data.materials.new("PK_Glass")
    nt, b = _nodes(m)
    b.inputs["Base Color"].default_value = (0.55, 0.85, 1.0, 1)
    b.inputs["Roughness"].default_value = 0.05
    b.inputs["Alpha"].default_value = 0.28
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Specular IOR Level"].default_value = 0.8
    m.diffuse_color = (0.6, 0.85, 1.0, 0.3)
    for attr, val in (("surface_render_method", "BLENDED"), ("use_transparency_overlap", True), ("use_backface_culling", False)):
        try:
            setattr(m, attr, val)
        except Exception:
            pass


def make_thread_material():
    # wound thread: vertex colour x fine horizontal windings (Godot: a thread look by name)
    m = bpy.data.materials.get("PK_ThreadVC") or bpy.data.materials.new("PK_ThreadVC")
    nt, b = _nodes(m)
    a = _attr(nt)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave"); wave.wave_type = "BANDS"; wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = 16.0; wave.inputs["Distortion"].default_value = 0.3
    wave.inputs["Detail"].default_value = 1.0
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["From Min"].default_value = 0.0; ramp.inputs["From Max"].default_value = 1.0
    ramp.inputs["To Min"].default_value = 0.32; ramp.inputs["To Max"].default_value = 1.06
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Value"])
    mul = nt.nodes.new("ShaderNodeVectorMath"); mul.operation = "SCALE"
    nt.links.new(a.outputs["Color"], mul.inputs[0]); nt.links.new(ramp.outputs[0], mul.inputs["Scale"])
    nt.links.new(mul.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.7; b.inputs["Sheen Weight"].default_value = 0.15
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.004
    nt.links.new(wave.outputs["Fac"], bump.inputs["Height"]); nt.links.new(bump.outputs[0], b.inputs["Normal"])
    m.diffuse_color = (0.6, 0.05, 0.06, 1)
    # matte birch: weaker grain, no coat
    w = bpy.data.materials["PK_WoodVC"].node_tree
    for n in w.nodes:
        if n.bl_idname == "ShaderNodeTexWave":
            n.inputs["Scale"].default_value = 9.0; n.inputs["Distortion"].default_value = 4.0
        if n.bl_idname == "ShaderNodeMix":
            n.inputs["Factor"].default_value = 0.14
        if n.bl_idname == "ShaderNodeBsdfPrincipled":
            n.inputs["Roughness"].default_value = 0.72; n.inputs["Coat Weight"].default_value = 0.0
