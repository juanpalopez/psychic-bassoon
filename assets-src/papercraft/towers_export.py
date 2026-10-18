
# towers_export.py - export the hi-def towers, the guard and the Camp Cook as animated GLBs.
# Run in Blender with the look-dev file open (or headless with -b):
#   exec(open("<repo>/assets-src/papercraft/towers_export.py").read())
# Each model is rebuilt at the origin in a scratch scene, then:
# - every surface but glass is merged into one material, PK_Craft, and the look each face
#   wants goes into a second UV map (UV2.x: 0 paper, 1 wood, 2 metal, 3 dimpled metal,
#   4 thread, 5 corrugated card) so that a part is one draw call (render/paper/craft_vc);
# - each clip becomes an NLA track of that name on every animated part, keyed at 12 fps (the
#   exporter writes LINEAR samplers on every frame; import the GLBs at animation/fps=12 and
#   StopMotion steps them with nearest interpolation). Every clip keys every
#   channel any clip moves (Godot resets the others), and an aiming tower gets an `*_Aim`
#   empty above its Head that no clip moves, for the game to turn.
import bpy, math, os
from mathutils import Vector, Euler

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else \
    "/Users/juanlopezguzman/Documents/projects/psychic-bassoon-towers/assets-src/papercraft"
NS = {"__file__": os.path.join(HERE, "towers_hd.py")}
exec(compile(open(os.path.join(HERE, "towers_hd.py")).read(), os.path.join(HERE, "towers_hd.py"), "exec"), NS)
for mod in ("tower_spool_guard.py", "tower_thimble_mortar.py", "tower_prism_spire.py", "tower_guard_tent.py",
            "tower_mess_tent.py", "unit_guard.py", "unit_camp_cook.py"):
    NS["load_tower"](mod)
GODOT = os.path.normpath(os.path.join(HERE, "..", "..", "godot", "assets", "models"))
AIMS = ("spool_guard", "thimble_mortar")
KIND = {"PK_PaperVC": 0, "PK_WoodVC": 1, "PK_MetalVC": 2, "PK_ThreadVC": 4, "PK_Corrugated": 5}
ITEMS = [
    ("towers/spool_guard.glb", "build_spool_guard", "anim_spool_guard", {}, "spool_guard"),
    ("towers/thimble_mortar.glb", "build_thimble_mortar", "anim_thimble_mortar", {}, "thimble_mortar"),
    ("towers/prism_spire.glb", "build_prism_spire", "anim_prism_spire", {}, "prism_spire"),
    ("towers/guard_tent.glb", "build_guard_tent", "anim_guard_tent", {}, "guard_tent"),
    ("towers/kitchen_mess_tent.glb", "build_mess_tent", "anim_mess_tent", {}, "mess_tent"),
    ("units/guard.glb", "build_guard", "anim_guard", {"name": "Guard"}, "guard"),
    ("heroes/camp_cook.glb", "build_camp_cook", "anim_camp_cook", {"name": "CampCook"}, "camp_cook"),
]


def craft(o):
    """One PK_Craft surface (plus PK_Glass), the look of each face in UV2.x."""
    me = o.data
    names = [m.name for m in me.materials]
    uv = me.uv_layers.new(name="UVKind")
    col = me.color_attributes["Col"]
    glass = "PK_Glass" in names
    for p in me.polygons:
        name = names[p.material_index]
        kind = KIND.get(name, 0)
        for li in p.loop_indices:
            c = list(col.data[li].color)
            k = kind
            if kind == 2 and c[3] > 0.5:
                k = 3
            if kind != 0:
                c[3] = 0.0          # only paper glows
            col.data[li].color = c
            uv.data[li].uv = (float(k), 0.0)
    slots = [1 if (glass and names[p.material_index] == "PK_Glass") else 0 for p in me.polygons]
    me.materials.clear()
    me.materials.append(bpy.data.materials.get("PK_Craft") or bpy.data.materials.new("PK_Craft"))
    if glass:
        me.materials.append(bpy.data.materials["PK_Glass"])
    for p, s in zip(me.polygons, slots):          # set after the slots change, which resets them
        p.material_index = s


def add_aim_pivot(objs, key):
    """Give an aiming tower an `*_Aim` empty above its Head, at the Head's rest place. No clip
    moves it, so the game can turn it to the target while the Head's clips play."""
    if key not in AIMS:
        return
    rest = NS["REST"]
    head_name = next(n for n in objs if n.endswith("_Head"))
    head = objs[head_name]
    aim = bpy.data.objects.new(head_name.replace("_Head", "_Aim"), None)
    head.users_collection[0].objects.link(aim)
    aim.parent = head.parent
    aim.location = head.location.copy()
    aim.rotation_euler = head.rotation_euler.copy()
    head.parent = aim
    head.location = (0.0, 0.0, 0.0)
    head.rotation_euler = (0.0, 0.0, 0.0)
    rest[head_name] = ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0))


def clips_to_nla(objs, key):
    """Each clip becomes an NLA track named after it on every animated part. Godot's mixer does
    not promise what a channel holds when the playing clip has no track for it, so every clip
    keys every channel that any clip moves on every animated part (at rest when the clip
    leaves it alone)."""
    rest = NS["REST"]
    clips = NS["CLIPS"][key]
    anims = NS["ANIMS"][key]
    used = {}
    for clip, length, loop in clips:
        for name, keys in anims.get(clip, {}).items():
            for ch, i in (("location", 1), ("rotation_quaternion", 2), ("scale", 3)):
                if any(k[i] is not None for k in keys):
                    used.setdefault(name, set()).add(ch)
    for name, o in objs.items():
        o.rotation_mode = "QUATERNION"
        o.animation_data_clear()
        if name not in used:
            continue
        ad = o.animation_data_create()
        rl, rr = Vector(rest[name][0]), rest[name][1]
        def pose(loc, rot, scl):
            o.location = rl + Vector(loc or (0, 0, 0))
            r = rot or (0, 0, 0)
            o.rotation_quaternion = Euler((rr[0] + math.radians(r[0]), rr[1] + math.radians(r[1]), rr[2] + math.radians(r[2])), "XYZ").to_quaternion()
            o.scale = Vector(scl or (1, 1, 1))
        chans = sorted(used[name])
        for clip, length, loop in clips:
            keys = sorted(anims.get(clip, {}).get(name) or [(0, None, None, None)], key=lambda k: k[0])
            end = keys[0] if loop else keys[-1]
            if keys[-1][0] < length:
                keys = keys + [(length, end[1], end[2], end[3])]
            act = bpy.data.actions.new(key + "." + clip + "." + name)
            ad.action = act
            for (f, loc, rot, scl) in keys:
                pose(loc, rot, scl)
                for ch in chans:
                    o.keyframe_insert(ch, frame=f)
            for fc in NS["_fcurves"](ad):
                for kp in fc.keyframe_points:
                    kp.interpolation = "CONSTANT"
            slot = ad.action_slot if hasattr(ad, "action_slot") else None
            ad.action = None
            tr = ad.nla_tracks.new()
            tr.name = clip
            st = tr.strips.new(clip, 0, act)
            if slot is not None and hasattr(st, "action_slot"):
                try:
                    st.action_slot = slot
                except Exception:
                    pass
            tr.mute = True
        pose(None, None, None)


def export_all(only=None):
    report = {}
    src = bpy.context.window.scene
    sc = bpy.data.scenes.get("Export") or bpy.data.scenes.new("Export")
    bpy.context.window.scene = sc
    sc.render.fps = 12; sc.frame_start = 0; sc.frame_end = 48
    NS["make_materials"](); NS["make_thread_material"]()
    props = set(bpy.ops.export_scene.gltf.get_rna_type().properties.keys())
    for rel, build, anim, kw, key in ITEMS:
        if only and key not in only:
            continue
        for o in list(sc.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        coll = sc.collection
        objs = NS[build](coll, (0.0, 0.0, 0.0), **kw)
        if kw.get("name"):
            NS[anim](kw["name"], key)
        else:
            NS[anim]()
        for o in objs.values():
            craft(o)
        add_aim_pivot(objs, key)
        clips_to_nla(objs, key)
        for o in sc.objects:
            o.select_set(True)
        bpy.context.view_layer.objects.active = list(objs.values())[0]
        path = os.path.join(GODOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        opts = dict(filepath=path, export_format="GLB", use_selection=True, use_active_scene=True, export_yup=True,
                    export_apply=False, export_animations=True, export_animation_mode="NLA_TRACKS",
                    export_force_sampling=False, export_frame_range=False, export_anim_slide_to_zero=False,
                    export_optimize_animation_size=False, export_optimize_animation_keep_anim_object=True,
                    export_optimize_animation_keep_anim_armature=True, export_bake_animation=False, export_vertex_color="NAME",
                    export_vertex_color_name="Col", export_all_vertex_colors=False, export_materials="EXPORT",
                    export_cameras=False, export_lights=False, export_texcoords=True, export_normals=True,
                    export_tangents=False, export_morph=False, export_skins=False, export_extras=False,
                    export_anim_single_armature=False, export_reset_pose_bones=False)
        opts = {k: v for k, v in opts.items() if k in props or k == "filepath"}
        bpy.ops.export_scene.gltf(**opts)
        report[rel] = {"tris": sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs.values()),
                       "parts": len(objs), "clips": [c[0] for c in NS["CLIPS"][key]]}
        for o in list(sc.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if a.users == 0:
            bpy.data.actions.remove(a)
    bpy.context.window.scene = src
    return report


if __name__ == "__main__" or "EXPORT_NOW" in globals():
    print(export_all())
