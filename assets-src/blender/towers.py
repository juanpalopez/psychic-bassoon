"""Scrapline towers: procedural low-poly models built in Blender.

Builds the Ballista, Catapult, Frost Spire and Storm Spire at levels 0-2,
exports one GLB per tower level and renders a preview sheet.

Run inside Blender (Scripting tab):
    exec(open('<repo>/assets-src/blender/towers.py').read())
or headless:
    SCRAPLINE_ROOT=<repo> blender -b -P towers.py

Conventions the game relies on (see src/render/models/glb.ts):
- origin at the centre of the base, one grid cell is 1 unit, footprint
  about 0.84 across;
- the weapon faces glTF +z, which is Blender -Y;
- one material with one colour-swatch texture: the loader keeps only
  position, normal and uv, so colour comes from UVs pointing at swatches.
"""

import json
import math
import os
import traceback

import bpy  # first: it registers bmesh and mathutils
import bmesh
from mathutils import Euler, Matrix, Vector

def _repo_root():
    """The repo root: $SCRAPLINE_ROOT, else two folders above this script
    (or above the .blend when run from Blender's text editor)."""
    env = os.environ.get('SCRAPLINE_ROOT')
    if env:
        return env
    here = globals().get('__file__') or bpy.data.filepath
    return os.path.abspath(os.path.join(os.path.dirname(here), '..', '..'))


ROOT = _repo_root()
SRC = os.path.join(ROOT, 'assets-src', 'blender')
EXPORT = os.path.join(SRC, 'export')
LOG = os.path.join(SRC, 'run.log')

# --- palette: a 4x4 grid of 16 px swatches in a 64 px texture ------------
# 16 px swatches survive mipmapping down to 4x4 without bleeding.
PALETTE = [
    ('stone_dark', 0x4A505E),
    ('stone', 0x6E7586),
    ('stone_light', 0x9AA0B0),
    ('wood_dark', 0x5A3A22),
    ('wood', 0xA06A3A),
    ('iron', 0x2D3138),
    ('brass', 0xC89B3C),
    ('teal', 0x3DDBD9),
    ('orange', 0xFF8A3D),
    ('violet', 0xA48CFF),
    ('violet_light', 0xD2C8FF),
    ('yellow', 0xFFE04A),
    ('yellow_light', 0xFFFBD0),
    ('pip_off', 0x39424F),
    ('pip_on', 0xF2C45A),
    ('teal_light', 0xB5FFFD),
]
SWATCH = {name: i for i, (name, _) in enumerate(PALETTE)}
TEX = 64
GRID = 4


def swatch_uv(name):
    i = SWATCH[name]
    col, row = i % GRID, i // GRID
    # row 0 at the top of the image; Blender UV v grows upwards
    return ((col + 0.5) / GRID, 1.0 - (row + 0.5) / GRID)


def palette_image():
    path = os.path.join(SRC, 'palette.png')
    img = bpy.data.images.get('scrapline_palette')
    if img is None:
        img = bpy.data.images.new('scrapline_palette', TEX, TEX, alpha=False)
    px = [0.0] * (TEX * TEX * 4)
    cell = TEX // GRID
    for i, (_, hexval) in enumerate(PALETTE):
        r = ((hexval >> 16) & 255) / 255
        g = ((hexval >> 8) & 255) / 255
        b = (hexval & 255) / 255
        col, row = i % GRID, i // GRID
        for y in range(cell):
            # pixel rows start at the bottom of the image
            py = TEX - 1 - (row * cell + y)
            for x in range(cell):
                o = (py * TEX + col * cell + x) * 4
                px[o:o + 4] = [r, g, b, 1.0]
    img.pixels = px
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    return img


def palette_material(img):
    mat = bpy.data.materials.get('scrapline_palette')
    if mat is None:
        mat = bpy.data.materials.new('scrapline_palette')
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.interpolation = 'Closest'
    bsdf.inputs['Roughness'].default_value = 0.9
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return mat


# --- mesh building ---------------------------------------------------------
class Builder:
    """Collects parts into one bmesh, each part painted with one swatch."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()

    def _paint(self, verts, colour):
        u, v = swatch_uv(colour)
        faces = {f for vert in verts for f in vert.link_faces}
        for f in faces:
            for loop in f.loops:
                loop[self.uv].uv = (u, v)

    @staticmethod
    def _matrix(loc, rot, scale, parent):
        m = (
            Matrix.Translation(Vector(loc))
            @ Euler(rot, 'XYZ').to_matrix().to_4x4()
            @ Matrix.Diagonal((*scale, 1.0))
        )
        return parent @ m if parent is not None else m

    def box(self, colour, size, loc, rot=(0, 0, 0), parent=None):
        m = self._matrix(loc, rot, size, parent)
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        self._paint(res['verts'], colour)

    def cyl(self, colour, r1, r2, h, seg, base, rot=(0, 0, 0), parent=None):
        """Frustum standing on `base` (r1 at the bottom), before `rot`."""
        m = self._matrix((0, 0, 0), (0, 0, 0), (1, 1, 1), None)
        m = (
            Matrix.Translation(Vector(base))
            @ Euler(rot, 'XYZ').to_matrix().to_4x4()
            @ Matrix.Translation((0, 0, h / 2))
        )
        if parent is not None:
            m = parent @ m
        res = bmesh.ops.create_cone(
            self.bm,
            cap_ends=True,
            cap_tris=False,
            segments=seg,
            radius1=r1,
            radius2=r2,
            depth=h,
            matrix=m,
        )
        self._paint(res['verts'], colour)

    def ball(self, colour, r, loc, parent=None):
        m = self._matrix(loc, (0, 0, 0), (1, 1, 1), parent)
        res = bmesh.ops.create_icosphere(
            self.bm, subdivisions=1, radius=r, matrix=m
        )
        self._paint(res['verts'], colour)

    def crystal(self, colour, r, h, base, rot=(0, 0, 0), seg=6):
        """Faceted double point: a short foot and a long tip."""
        foot = h * 0.22
        pivot = (
            Matrix.Translation(Vector(base))
            @ Euler(rot, 'XYZ').to_matrix().to_4x4()
        )
        self.cyl(colour, 0.0, r, foot, seg, (0, 0, 0), parent=pivot)
        self.cyl(colour, r, 0.0, h - foot, seg, (0, 0, foot), parent=pivot)

    def torus(self, colour, R, r, z, seg=12, ring=4):
        verts = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            ca, sa = math.cos(a), math.sin(a)
            row = []
            for j in range(ring):
                b = 2 * math.pi * j / ring + math.pi / 4
                d = R + r * math.cos(b)
                row.append(
                    self.bm.verts.new((d * ca, d * sa, z + r * math.sin(b)))
                )
            verts.append(row)
        for i in range(seg):
            for j in range(ring):
                a, b = verts[i][j], verts[(i + 1) % seg][j]
                c = verts[(i + 1) % seg][(j + 1) % ring]
                d = verts[i][(j + 1) % ring]
                self.bm.faces.new((a, b, c, d))
        self._paint([v for row in verts for v in row], colour)

    def beam(self, colour, thick, a, b):
        """Square beam between two points."""
        a, b = Vector(a), Vector(b)
        d = b - a
        length = d.length
        rot = Vector((0, 1, 0)).rotation_difference(d.normalized())
        m = (
            Matrix.Translation((a + b) / 2)
            @ rot.to_matrix().to_4x4()
            @ Matrix.Diagonal((thick, length, thick, 1.0))
        )
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        self._paint(res['verts'], colour)

    def to_object(self, name, mat, collection):
        mesh = bpy.data.meshes.get(name)
        if mesh is not None:
            bpy.data.meshes.remove(mesh)
        mesh = bpy.data.meshes.new(name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        self.bm.to_mesh(mesh)
        self.bm.free()
        mesh.materials.append(mat)
        for poly in mesh.polygons:
            poly.use_smooth = False
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
        return obj


# --- shared tower parts ------------------------------------------------------
PLINTH_H = 0.14
BODY_H = (0.0, 0.28, 0.5)


def plinth(b, level):
    """Round stone plinth with three level pips facing the front."""
    b.cyl('stone_dark', 0.42, 0.38, PLINTH_H, 10, (0, 0, 0))
    for i in range(3):
        b.box(
            'pip_on' if i <= level else 'pip_off',
            (0.07, 0.04, 0.035),
            ((i - 1) * 0.11, -0.385, 0.075),
        )


def body(b, level):
    """Stone tower section; each level makes it taller. Returns its top."""
    z = PLINTH_H
    h = BODY_H[level]
    if h == 0:
        b.cyl('stone', 0.34, 0.33, 0.04, 8, (0, 0, z))
        return z + 0.04
    b.cyl('stone', 0.32, 0.29, h, 8, (0, 0, z))
    if level == 2:
        b.cyl('stone_light', 0.31, 0.31, 0.04, 8, (0, 0, z + h * 0.45))
    top = z + h
    b.cyl('stone_light', 0.34, 0.34, 0.05, 8, (0, 0, top))
    top += 0.05
    if level == 2:
        for i in range(8):
            a = 2 * math.pi * (i + 0.5) / 8
            if abs(math.sin(a) + 1) < 0.2:
                continue  # keep the front open so the weapon reads
            b.box(
                'stone_light',
                (0.09, 0.06, 0.08),
                (math.cos(a) * 0.29, math.sin(a) * 0.29, top + 0.04),
                (0, 0, a),
            )
    return top


# --- towers -------------------------------------------------------------------
def ballista(level):
    b = Builder()
    plinth(b, level)
    t = body(b, level)
    if level >= 1:
        n = 2 if level == 1 else 4
        for i in range(n):
            a = math.pi * (0.25 + i / n * 2) if n == 4 else math.pi * i
            b.crystal(
                'teal',
                0.05,
                0.2,
                (math.cos(a) * 0.3, math.sin(a) * 0.3, t - 0.16),
                (0, 0.5, a),
            )
    b.cyl('iron', 0.2, 0.18, 0.06, 10, (0, 0, t))
    b.box('wood_dark', (0.1, 0.1, 0.12), (0, 0, t + 0.12))
    pitch = Matrix.Translation((0, 0, t + 0.2)) @ Euler(
        (-0.12, 0, 0), 'XYZ'
    ).to_matrix().to_4x4()
    b.box('wood', (0.09, 0.62, 0.08), (0, -0.04, 0.02), parent=pitch)
    b.box('teal', (0.07, 0.07, 0.07), (0, 0.22, 0.07), parent=pitch)
    span = 0.34 + 0.04 * level
    sweep = 0.38
    for side in (-1, 1):
        root = Vector((0, -0.3, 0.04))
        tip = root + Vector((side * math.cos(sweep) * span,
                             math.sin(sweep) * span, 0.0))
        b.beam('wood_dark', 0.05, pitch @ root, pitch @ tip)
        b.box('teal', (0.06, 0.06, 0.06), tip, (0, 0, math.pi / 4),
              parent=pitch)
        b.beam('teal_light', 0.012, pitch @ tip,
               pitch @ Vector((0, 0.02, 0.06)))
    count = 1 + level
    for i in range(count):
        x = (i - (count - 1) / 2) * 0.06
        b.box('teal_light', (0.025, 0.5, 0.025), (x, -0.13, 0.075),
              parent=pitch)
        tip_base = Matrix.Translation((x, -0.38, 0.075)) @ Euler(
            (math.pi / 2, 0, 0), 'XYZ').to_matrix().to_4x4()
        b.cyl('teal', 0.035, 0.0, 0.09, 4, (0, 0, 0),
              parent=pitch @ tip_base)
    return b


def catapult(level):
    b = Builder()
    plinth(b, level)
    t = body(b, level)
    z = t + 0.02
    for x in (-0.16, 0.16):
        b.box('wood', (0.06, 0.6, 0.06), (x, 0, z + 0.09))
    for y in (-0.24, 0.24):
        b.box('wood', (0.38, 0.06, 0.05), (0, y, z + 0.09))
    for x in (-0.22, 0.22):
        for y in (-0.2, 0.2):
            b.cyl('wood_dark', 0.09, 0.09, 0.04, 8, (x - 0.02, y, z + 0.09),
                  (0, math.pi / 2, 0))
    apex_z = z + 0.42
    for x in (-0.16, 0.16):
        for y in (-0.15, 0.15):
            b.beam('wood', 0.05, (x, y, z + 0.12), (x, 0.0, apex_z))
    b.cyl('iron', 0.03, 0.03, 0.44, 6, (-0.22, 0, apex_z),
          (0, math.pi / 2, 0))
    for x in (-0.2, 0.17):
        b.cyl('orange', 0.045, 0.045, 0.03, 6, (x, 0, apex_z),
              (0, math.pi / 2, 0))
    # throwing arm at rest: the cup end low at the back (+Y)
    arm_len = 0.62 + 0.06 * level
    pivot = Matrix.Translation((0, 0, apex_z)) @ Euler(
        (-0.55, 0, 0), 'XYZ').to_matrix().to_4x4()
    back = arm_len * 0.68
    b.box('wood', (0.075, arm_len, 0.075), (0, back - arm_len / 2, 0),
          parent=pivot)
    b.box('wood_dark', (0.17, 0.17, 0.07), (0, back, 0.05), parent=pivot)
    b.ball('orange' if level == 2 else 'stone_light', 0.065,
           (0, back, 0.13), parent=pivot)
    if level >= 1:
        front = -(arm_len - back)
        b.box('iron', (0.15, 0.12, 0.13), (0, front, -0.08), parent=pivot)
        b.box('brass', (0.16, 0.02, 0.14), (0, front, -0.08), parent=pivot)
    if level == 2:
        b.box('wood_dark', (0.025, 0.025, 0.36), (0.19, 0.27, z + 0.3))
        b.box('orange', (0.01, 0.14, 0.09), (0.19, 0.2, z + 0.42))
    return b


def frost_spire(level):
    b = Builder()
    plinth(b, level)
    t = body(b, level)
    b.cyl('brass', 0.22, 0.17, 0.07, 8, (0, 0, t))
    t += 0.07
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        b.beam('brass', 0.035, (math.cos(a) * 0.17, math.sin(a) * 0.17, t),
               (math.cos(a) * 0.2, math.sin(a) * 0.2, t + 0.12))
    main_h = 0.42 + 0.1 * level
    b.crystal('violet', 0.1, main_h, (0, 0, t - 0.02))
    n = 2 + 2 * level
    for i in range(n):
        a = 2 * math.pi * i / n + math.pi / 2
        b.crystal(
            'violet_light' if i % 2 else 'violet',
            0.045,
            0.17 + 0.03 * (i % 2),
            (math.cos(a) * 0.12, math.sin(a) * 0.12, t),
            (0, 0.5, a),
        )
    if level == 2:
        b.torus('violet_light', 0.21, 0.02, t + main_h * 0.45)
    return b


def storm_spire(level):
    b = Builder()
    plinth(b, level)
    t = body(b, level)
    b.cyl('iron', 0.12, 0.08, 0.32, 8, (0, 0, t))
    b.cyl('brass', 0.13, 0.12, 0.04, 8, (0, 0, t + 0.1))
    top = t + 0.32
    b.cyl('brass', 0.09, 0.16, 0.08, 8, (0, 0, top))
    top += 0.08
    count = 4 + 2 * level
    tips = []
    for i in range(count):
        a = 2 * math.pi * i / count
        base = (math.cos(a) * 0.13, math.sin(a) * 0.13, top - 0.01)
        b.cyl('brass', 0.03, 0.0, 0.24, 5, base, (0, 0.5, a))
        lean = Euler((0, 0.5, a), 'XYZ').to_matrix() @ Vector((0, 0, 0.24))
        tips.append(Vector(base) + lean)
    b.crystal('yellow', 0.09, 0.34, (0, 0, top - 0.02))
    if level >= 1:
        b.torus('yellow_light', 0.17, 0.018, top + 0.12)
    if level == 2:
        for tip in tips[::2]:
            b.ball('yellow', 0.03, tip)
    return b


TOWERS = [
    ('ballista', ballista),
    ('catapult', catapult),
    ('frost-spire', frost_spire),
    ('storm-spire', storm_spire),
]


# --- export and preview ------------------------------------------------------
def export_glb(obj, path):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    wanted = dict(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_texcoord=True,
        export_normals=True,
        export_materials='EXPORT',
        export_animations=False,
        export_draco_mesh_compression_enable=False,
    )
    # option names drift between Blender versions; pass only known ones
    known = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(**{k: v for k, v in wanted.items() if k in known})


def render_sheet(scene, objects, path):
    cols = len(TOWERS)
    for (name, level), obj in objects.items():
        col = [n for n, _ in TOWERS].index(name)
        obj.location = ((col - (cols - 1) / 2) * 1.15, level * 1.3, 0)
    cam_data = bpy.data.cameras.new('preview_cam')
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 5.6
    cam = bpy.data.objects.new('preview_cam', cam_data)
    scene.collection.objects.link(cam)
    # look from the front (-Y) and above, like the game camera
    target = Vector((0, 1.3, 0.55))
    direction = Vector((0.45, -1.0, 0.85)).normalized()
    cam.location = target + direction * 12
    cam.rotation_euler = (
        (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
    )
    scene.camera = cam
    scene.render.engine = 'BLENDER_WORKBENCH'
    # show palette colours as authored, as the game's Lambert material does
    scene.view_settings.view_transform = 'Standard'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    if scene.world is None:
        scene.world = bpy.data.worlds.new('preview_world')
    scene.world.color = (0.03, 0.04, 0.07)
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for obj in objects.values():
        obj.location = (0, 0, 0)


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def main():
    os.makedirs(EXPORT, exist_ok=True)
    scene = bpy.data.scenes.get('scrapline_towers')
    if scene is None:
        scene = bpy.data.scenes.new('scrapline_towers')
    for obj in list(scene.collection.all_objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    window = getattr(bpy.context, 'window', None)
    if window is not None:
        window.scene = scene
    if bpy.context.scene != scene:
        raise RuntimeError('could not switch to the scrapline_towers scene')

    mat = palette_material(palette_image())
    objects = {}
    report = {'blender': bpy.app.version_string, 'models': {}}
    for name, build in TOWERS:
        for level in range(3):
            key = f'{name}-{level}'
            obj = build(level).to_object(key, mat, scene.collection)
            objects[(name, level)] = obj
            path = os.path.join(EXPORT, f'{key}.glb')
            export_glb(obj, path)
            dims = obj.dimensions
            report['models'][key] = {
                'triangles': triangles(obj),
                'size': [round(dims.x, 3), round(dims.y, 3), round(dims.z, 3)],
                'bytes': os.path.getsize(path),
            }
    render_sheet(scene, objects, os.path.join(SRC, 'towers-preview.png'))
    with open(os.path.join(SRC, 'report.json'), 'w') as f:
        json.dump(report, f, indent=2)
    if bpy.data.filepath == '' or os.environ.get('SCRAPLINE_SAVE'):
        bpy.ops.wm.save_as_mainfile(
            filepath=os.path.join(SRC, 'towers.blend'), copy=True
        )
    return report


def run():
    os.makedirs(SRC, exist_ok=True)
    try:
        report = main()
        msg = 'OK ' + json.dumps(report)
    except Exception:
        msg = 'ERROR\n' + traceback.format_exc()
    with open(LOG, 'w') as f:
        f.write(msg + '\n')
    print(msg)


run()
