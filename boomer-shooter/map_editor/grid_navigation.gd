class_name GridNavigation
extends Node

var grid_size := 1.5
var graph := AStar2D.new()
var cell_to_point: Dictionary = {}
var wall_edges: Dictionary = {}


func setup(floor_records: Array, wall_records: Array, p_grid_size: float) -> void:
	grid_size = maxf(p_grid_size, 0.001)
	graph.clear()
	cell_to_point.clear()
	wall_edges.clear()

	for record in wall_records:
		wall_edges[String(record["key"])] = true

	var next_point_id := 0
	for record in floor_records:
		var cell_min: Vector2i = record["cell_min"]
		var cell_max: Vector2i = record["cell_max"]
		for x in range(cell_min.x, cell_max.x + 1):
			for y in range(cell_min.y, cell_max.y + 1):
				var cell := Vector2i(x, y)
				if cell_to_point.has(cell):
					continue
				var point_id := next_point_id
				next_point_id += 1
				cell_to_point[cell] = point_id
				graph.add_point(point_id, _cell_world_position_2d(cell))

	for cell_value in cell_to_point.keys():
		var cell: Vector2i = cell_value
		for offset in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbour: Vector2i = cell + offset
			if not cell_to_point.has(neighbour):
				continue
			if _has_wall_between(cell, neighbour):
				continue
			graph.connect_points(
				cell_to_point[cell], cell_to_point[neighbour], true)

	add_to_group(&"grid_navigation")


func find_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if graph.get_point_count() == 0:
		return result
	var from_id := _get_nearest_point_id(from)
	var to_id := _get_nearest_point_id(to)
	if from_id < 0 or to_id < 0:
		return result
	var point_path := graph.get_point_path(from_id, to_id)
	if point_path.is_empty():
		return result
	for point in point_path:
		result.append(Vector3(point.x, from.y, point.y))
	return result

func _get_nearest_point_id(position: Vector3) -> int:
	var cell := Vector2i(
		floori(position.x / grid_size),
		floori(position.z / grid_size))
	if cell_to_point.has(cell):
		return cell_to_point[cell]
	return graph.get_closest_point(Vector2(position.x, position.z), false)


func _cell_world_position_2d(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5) * grid_size


func _has_wall_between(cell_a: Vector2i, cell_b: Vector2i) -> bool:
	var delta := cell_b - cell_a
	var point_a: Vector2i
	var point_b: Vector2i
	if delta.x != 0:
		var boundary_x := maxi(cell_a.x, cell_b.x)
		point_a = Vector2i(boundary_x, cell_a.y)
		point_b = point_a + Vector2i.DOWN
	else:
		var boundary_y := maxi(cell_a.y, cell_b.y)
		point_a = Vector2i(cell_a.x, boundary_y)
		point_b = point_a + Vector2i.RIGHT
	return wall_edges.has(_get_edge_key(point_a, point_b))


func _get_edge_key(point_a: Vector2i, point_b: Vector2i) -> String:
	if point_b.x < point_a.x or (
		point_b.x == point_a.x and point_b.y < point_a.y
	):
		var swap := point_a
		point_a = point_b
		point_b = swap
	return "%d,%d:%d,%d" % [point_a.x, point_a.y, point_b.x, point_b.y]
