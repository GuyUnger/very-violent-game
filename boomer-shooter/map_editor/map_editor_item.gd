class_name MapEditorItem
extends Resource

enum Category {
	WALLS,
	FLOORS,
	NPCS,
	PROPS,
	WALLPAPERS,
	ITEMS,
	META,
}

@export var id: StringName
@export var display_name: String
@export var category := Category.WALLS
@export var show_in_palette := true
@export var scene: PackedScene
@export var surface: SurfaceDefinition
@export var thumbnail: Texture2D
@export var footprint := Vector2i.ONE
## Local X/Z offset measured in tile widths. For example, (0, -0.5)
## places the item on the back border of its tile.
@export var placement_offset := Vector2.ZERO
