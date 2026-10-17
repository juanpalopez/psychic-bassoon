
# towers_hd.py - the hi-def papercraft towers: build, animate and stage them for look-dev.
# Run in Blender with the look-dev file open:
#   exec(open("<repo>/assets-src/papercraft/towers_hd.py").read())
# Each tower is at most three mesh parts (Base, Head, and one action part) animated as
# whole parts (no skeleton), keyed every frame at 12 fps with constant interpolation so
# it steps like stop-motion. Animations are data (ANIMS) so the preview timeline and the
# export actions come from the same keys.
import bpy, math, os
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else \
    "/Users/juanlopezguzman/Documents/projects/psychic-bassoon-towers/assets-src/papercraft"
NS = globals()
for mod in ("towers_lib.py",):
    exec(compile(open(os.path.join(HERE, mod)).read(), os.path.join(HERE, mod), "exec"), NS)

FPS = 12
# name -> {part object name -> [(frame, loc, rot_euler_deg, scale)]}, frames from 0
ANIMS = {}
CLIPS = {}  # tower -> [(clip name, frames, loop)]


def coll(name):
    c = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    return c


def clear_coll(c):
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for ch in list(c.children):
        clear_coll(ch); bpy.data.collections.remove(ch)


def track(tower, clip, part, frames):
    ANIMS.setdefault(tower, {}).setdefault(clip, {})[part] = frames


def ease(t):
    return t * t * (3.0 - 2.0 * t)


def apply_preview(tower_objs, tower, start=1):
    """Lay the tower's clips one after another on the timeline, from `start`."""
    f0 = start
    for clip, length, loop in CLIPS[tower]:
        for part, keys in ANIMS[tower][clip].items():
            o = tower_objs[part]
            rest = REST[part]
            for (f, loc, rot, scl) in keys:
                o.location = Vector(rest[0]) + Vector(loc or (0, 0, 0))
                r = rot or (0, 0, 0)
                o.rotation_euler = Euler((rest[1][0] + math.radians(r[0]), rest[1][1] + math.radians(r[1]),
                                          rest[1][2] + math.radians(r[2])), "XYZ")
                o.scale = Vector(scl or (1, 1, 1))
                for path in ("location", "rotation_euler", "scale"):
                    o.keyframe_insert(path, frame=f0 + f)
        f0 += length
    return f0


def constant_keys(objs):
    for o in objs:
        ad = o.animation_data
        if not ad or not ad.action:
            continue
        for fc in _fcurves(ad):
            for k in fc.keyframe_points:
                k.interpolation = "CONSTANT"


def _fcurves(ad):
    act = ad.action
    try:
        return list(act.fcurves)
    except Exception:
        pass
    out = []
    for layer in act.layers:
        for strip in layer.strips:
            cb = strip.channelbag(ad.action_slot)
            if cb:
                out.extend(cb.fcurves)
    return out


REST = {}  # part name -> (location, rotation radians)


def rest(o):
    REST[o.name] = (tuple(o.location), tuple(o.rotation_euler))
    return o


# ---------- the stage: the five sockets the look-dev board already has ----------
SOCKETS = {
    "spool_guard": (0.0, -1.0, 0.0),
    "thimble_mortar": (4.0, -4.0, 1.0),
    "prism_spire": (-2.0, -4.0, 0.0),
    "guard_tent": (4.0, -1.0, 0.0),
    "mess_tent": (7.0, -2.0, 0.0),
}


def camera(name, target, pitch_deg, dist, yaw_deg=0.0, fov_y=None, lens=50.0):
    cams = coll("TowerCams")
    cam = bpy.data.objects.get(name)
    if cam is None:
        cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
        cams.objects.link(cam)
    t = Vector(target)
    p = math.radians(pitch_deg); y = math.radians(yaw_deg)
    off = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p))) * dist
    cam.location = t + off
    cam.rotation_euler = (math.pi / 2 - p, 0.0, y)
    if fov_y:
        cam.data.sensor_fit = "VERTICAL"; cam.data.angle_y = math.radians(fov_y)
    else:
        cam.data.sensor_fit = "AUTO"; cam.data.lens = lens
    cam.data.clip_start = 0.1; cam.data.clip_end = 300
    return cam


LOOKDEV = os.path.normpath(os.path.join(HERE, "..", "tower_lookdev"))


def load_tower(mod):
    exec(compile(open(os.path.join(HERE, mod)).read(), os.path.join(HERE, mod), "exec"), NS)


def stage_tower(key, builder, animator, cam_args):
    """(Re)build one tower on its socket with its preview timeline and a close camera."""
    sc = bpy.data.scenes["Tower_LookDev"]
    towers = coll("Towers")
    tc = bpy.data.collections.get("T_" + key) or bpy.data.collections.new("T_" + key)
    if tc.name not in towers.children:
        towers.children.link(tc)
    clear_coll(tc)
    objs = builder(tc, SOCKETS[key])
    animator()
    apply_preview(objs, key, 1)
    constant_keys(objs.values())
    cam = camera(*cam_args)
    return objs, cam


def render_bg(cam, out, frames, res="1280x720", log="/tmp/pkd_render.log"):
    import subprocess
    bpy.ops.wm.save_mainfile()
    return subprocess.Popen([bpy.app.binary_path, "-b", bpy.data.filepath, "-P",
                             os.path.join(LOOKDEV, "render_frames.py"), "--", "Tower_LookDev", cam,
                             os.path.join(LOOKDEV, "renders", out), frames, res],
                            stdout=open(log, "w"), stderr=-2).pid


def tris(objs):
    return {n: sum(len(p.vertices) - 2 for p in o.data.polygons) for n, o in objs.items()}


def stage_unit(key, builder, animator, at, cam_args=None, **kw):
    """(Re)build one unit (guard, hero) at `at` with its preview timeline."""
    units = coll("Units")
    sc = bpy.data.scenes["Tower_LookDev"]
    if units.name not in sc.collection.children:
        sc.collection.children.link(units)
    uc = bpy.data.collections.get("U_" + key) or bpy.data.collections.new("U_" + key)
    if uc.name not in units.children:
        units.children.link(uc)
    clear_coll(uc)
    objs = builder(uc, at, **kw)
    animator(kw.get("name", None) or key, key) if "name" in kw else animator()
    apply_preview(objs, key, 1)
    constant_keys(objs.values())
    cam = camera(*cam_args) if cam_args else None
    return objs, cam
