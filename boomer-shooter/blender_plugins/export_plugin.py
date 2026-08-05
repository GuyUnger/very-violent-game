bl_info = {
    "name": "Quick GLB Export",
    "author": "Custom",
    "version": (1, 0, 0),
    "blender": (4, 0, 0),
    "location": "File > Export > Quick Export GLB",
    "description": "Export the current project to a configured GLB path",
    "category": "Import-Export",
}

import bpy
import os

from bpy.props import StringProperty
from bpy.types import AddonPreferences, Operator


ADDON_ID = __name__
addon_keymaps = []


def get_export_path(context):
    """Return the configured GLB path as an absolute path."""
    preferences = context.preferences.addons[ADDON_ID].preferences
    configured_path = bpy.path.abspath(preferences.export_path)

    # Allow selecting either a directory or a complete .glb filename.
    if configured_path.lower().endswith(".glb"):
        return configured_path

    # When only a directory is configured, use the .blend filename.
    blend_filepath = bpy.data.filepath

    if blend_filepath:
        filename = os.path.splitext(os.path.basename(blend_filepath))[0]
    else:
        filename = "untitled"

    return os.path.join(configured_path, f"{filename}.glb")


class QUICKGLB_Preferences(AddonPreferences):
    bl_idname = ADDON_ID

    export_path: StringProperty(
        name="Export Path",
        description=(
            "A destination directory or complete .glb filepath. "
            "Paths beginning with // are relative to the .blend file"
        ),
        subtype="FILE_PATH",
        default="//exports/",
    )

    def draw(self, context):
        layout = self.layout
        layout.prop(self, "export_path")

        box = layout.box()
        box.label(text="Examples:")
        box.label(text="//exports/")
        box.label(text="//exports/my_scene.glb")
        box.label(text="C:\\Projects\\game\\assets\\scene.glb")


class QUICKGLB_OT_export(Operator):
    bl_idname = "export_scene.quick_glb"
    bl_label = "Quick Export GLB"
    bl_description = "Export the current scene to the configured GLB path"
    bl_options = {"REGISTER"}

    def execute(self, context):
        export_path = get_export_path(context)
        export_directory = os.path.dirname(export_path)

        try:
            if export_directory:
                os.makedirs(export_directory, exist_ok=True)

            result = bpy.ops.export_scene.gltf(
                filepath=export_path,
                export_format="GLB",

                # Adjust these defaults as needed:
                use_selection=False,
                export_apply=True,
                export_animations=True,
            )

            if "FINISHED" not in result:
                self.report({"ERROR"}, "GLB export did not finish")
                return {"CANCELLED"}

        except Exception as exc:
            self.report({"ERROR"}, f"GLB export failed: {exc}")
            return {"CANCELLED"}

        self.report({"INFO"}, f"Exported GLB: {export_path}")
        return {"FINISHED"}


def export_menu(self, context):
    self.layout.operator(
        QUICKGLB_OT_export.bl_idname,
        text="Quick Export GLB",
    )


classes = (
    QUICKGLB_Preferences,
    QUICKGLB_OT_export,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)

    # Add beneath Blender's existing File > Export options.
    bpy.types.TOPBAR_MT_file_export.append(export_menu)

    # Ctrl + Shift + G in the 3D View.
    window_manager = bpy.context.window_manager
    keyconfig = window_manager.keyconfigs.addon

    if keyconfig:
        keymap = keyconfig.keymaps.new(
            name="3D View",
            space_type="VIEW_3D",
        )

        keymap_item = keymap.keymap_items.new(
            QUICKGLB_OT_export.bl_idname,
            type="G",
            value="PRESS",
            ctrl=True,
            shift=True,
        )

        addon_keymaps.append((keymap, keymap_item))


def unregister():
    for keymap, keymap_item in addon_keymaps:
        keymap.keymap_items.remove(keymap_item)

    addon_keymaps.clear()

    bpy.types.TOPBAR_MT_file_export.remove(export_menu)

    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()
