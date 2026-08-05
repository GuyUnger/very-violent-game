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
	OPENINGS,
	CEILINGS,
}

@export var id: StringName
@export var display_name: String
@export var category := Category.WALLS
@export var show_in_palette := true
@export var scene: PackedScene
@export var surface: SurfaceDefinition
@export var opening: WallOpeningDefinition
@export var thumbnail: Texture2D
@export var footprint := Vector2i.ONE
