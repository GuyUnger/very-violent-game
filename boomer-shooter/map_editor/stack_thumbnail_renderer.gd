class_name MapEditorStackThumbnailRenderer
extends SubViewport

const SURFACE_STACK_SCENE := preload(
	"res://map_editor/surface_stack_geometry.tscn")

@onready var preview_root: Node3D = $PreviewRoot


func render_surface(surface: SurfaceDefinition) -> Texture2D:
	if not surface:
		return null
	var layer := SurfaceLayerDefinition.new()
	layer.surface = surface
	var stack := SurfaceStackDefinition.new()
	var layers: Array[SurfaceLayerDefinition] = [null, layer, null]
	stack.layers = layers
	return await render_stack(stack)


func render_stack(surface_stack: SurfaceStackDefinition) -> Texture2D:
	for child in preview_root.get_children():
		preview_root.remove_child(child)
		child.free()

	if not surface_stack:
		return null

	var preview := SURFACE_STACK_SCENE.instantiate() as SurfaceStackGeometry
	if not preview:
		return null
	preview.surface_stack = surface_stack
	preview.size = Vector2.ONE
	preview.is_floor = false
	preview.show_editor_line = false
	preview_root.add_child(preview)

	# Let the stack build its generated geometry before requesting one frame.
	await get_tree().process_frame
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	var image := get_texture().get_image()
	if not image or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
