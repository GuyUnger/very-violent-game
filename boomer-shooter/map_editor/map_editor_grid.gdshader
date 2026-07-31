shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;

uniform float cell_size : hint_range(0.1, 10.0, 0.1) = 1.5;
uniform float line_width : hint_range(0.01, 0.2, 0.005) = 0.035;
uniform float major_line_width : hint_range(0.01, 0.3, 0.005) = 0.06;
uniform float major_every : hint_range(2.0, 16.0, 1.0) = 4.0;
uniform vec4 grid_color : source_color = vec4(0.34, 0.37, 0.40, 1.0);
uniform vec4 major_grid_color : source_color = vec4(0.52, 0.56, 0.60, 1.0);
uniform vec4 axis_x_color : source_color = vec4(0.65, 0.20, 0.20, 1.0);
uniform vec4 axis_z_color : source_color = vec4(0.20, 0.35, 0.65, 1.0);

varying vec3 world_position;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


float grid_line(vec2 position, float spacing, float width) {
	vec2 distance_to_line = abs(fract(position / spacing + 0.5) - 0.5) * spacing;
	vec2 antialias_width = max(fwidth(position), vec2(0.0001));
	vec2 lines = 1.0 - smoothstep(
		vec2(width),
		vec2(width) + antialias_width,
		distance_to_line
	);
	return max(lines.x, lines.y);
}


void fragment() {
	vec2 grid_position = world_position.xz;
	float minor = grid_line(grid_position, cell_size, line_width);
	float major = grid_line(grid_position, cell_size * major_every, major_line_width);

	vec3 color = grid_color.rgb;
	float alpha = minor * grid_color.a;
	color = mix(color, major_grid_color.rgb, major);
	alpha = max(alpha, major * major_grid_color.a);

	float x_axis = 1.0 - smoothstep(
		line_width,
		line_width + fwidth(grid_position.y),
		abs(grid_position.y)
	);
	float z_axis = 1.0 - smoothstep(
		line_width,
		line_width + fwidth(grid_position.x),
		abs(grid_position.x)
	);

	color = mix(color, axis_x_color.rgb, x_axis);
	color = mix(color, axis_z_color.rgb, z_axis);
	alpha = max(alpha, x_axis * axis_x_color.a);
	alpha = max(alpha, z_axis * axis_z_color.a);
	ALBEDO = color;
	ALPHA = alpha;
}
