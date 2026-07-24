shader_type spatial;
render_mode cull_disabled;

// Each texel stores one hit as (wall_uv.x, wall_uv.y, rotation_ratio, size_ratio).
uniform sampler2D holes : filter_nearest, repeat_disable;
uniform int hole_count = 0;

// The atlas is an evenly divided grid of alpha masks.
uniform sampler2D hole_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D edge_noise_texture : filter_linear_mipmap, repeat_enable;
uniform ivec2 hole_atlas_grid = ivec2(1, 1);
uniform vec2 hole_uv_size = vec2(0.08, 0.08);
uniform vec2 hole_size_random_range = vec2(0.85, 1.2);
uniform vec2 wall_chunk_size = vec2(1.0, 1.0);
uniform float broken = 0.0;
uniform float break_edge_width = 0.12;
uniform vec2 edge_noise_scale = vec2(5.0, 5.0);
uniform float edge_noise_strength = 0.08;
uniform float corrugated = 0.0;
instance uniform vec4 wall_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	VERTEX.y += sin(UV.x * 64.0) * 0.05 * corrugated;
}

void fragment() {
	float painted_alpha = 1.0;
	ivec2 hit_texture_size = textureSize(holes, 0);
	ivec2 atlas_grid = max(hole_atlas_grid, ivec2(1));
	int atlas_tile_count = atlas_grid.x * atlas_grid.y;
	vec2 chunk_size = max(wall_chunk_size, vec2(0.0001));
	float chunk_min_dimension = min(chunk_size.x, chunk_size.y);
	vec2 chunk_aspect = chunk_size / chunk_min_dimension;

	for (int hit_index = 0; hit_index < hole_count; hit_index++) {
		ivec2 hit_pixel = ivec2(
			hit_index % hit_texture_size.x,
			hit_index / hit_texture_size.x);
		vec4 hit_data = texelFetch(holes, hit_pixel, 0);
		float rotation = hit_data.b * TAU;
		float hole_size_scale = mix(
			hole_size_random_range.x,
			hole_size_random_range.y,
			hit_data.a);
		vec2 local_uv = ((UV - hit_data.rg) * chunk_aspect) / (hole_uv_size * hole_size_scale);
		float sin_theta = sin(rotation);
		float cos_theta = cos(rotation);
		vec2 hole_uv = vec2(
			cos_theta * local_uv.x - sin_theta * local_uv.y,
			sin_theta * local_uv.x + cos_theta * local_uv.y) + vec2(0.5);
		if (any(lessThan(hole_uv, vec2(0.0))) ||
				any(greaterThan(hole_uv, vec2(1.0)))) {
			continue;
		}

		// Give each hit a deterministic atlas tile without storing extra data.
		int atlas_index = (hit_index * 73 + 19) % atlas_tile_count;
		ivec2 atlas_tile = ivec2(
			atlas_index % atlas_grid.x,
			atlas_index / atlas_grid.x);
		vec2 atlas_uv = (vec2(atlas_tile) + hole_uv) / vec2(atlas_grid);
		vec3 hole_sample = texture(hole_atlas, atlas_uv).rgb;

		// White is outside the hole and leaves the wall untouched.
		if (all(greaterThanEqual(hole_sample, vec3(0.999)))) {
			continue;
		}

		// Black cuts alpha to zero; gray preserves anti-aliased edges.
		float hole_alpha = dot(hole_sample, vec3(0.299, 0.587, 0.114));
		painted_alpha = min(painted_alpha, hole_alpha);
	}

	if (broken > 0.5) {
		vec2 edge_distance_uv = min(UV, vec2(1.0) - UV) * chunk_aspect;
		float edge_distance = min(edge_distance_uv.x, edge_distance_uv.y);
		float edge_band = max(break_edge_width, 0.0001);
		float noise_value = texture(edge_noise_texture, UV * edge_noise_scale * chunk_aspect).r;
		float jagged_cutoff = clamp(
			break_edge_width - noise_value * edge_noise_strength,
			0.0,
			break_edge_width);
		float edge_alpha = 1.0 - smoothstep(
			jagged_cutoff,
			jagged_cutoff + edge_band * 0.35,
			edge_distance);
		painted_alpha = min(painted_alpha, edge_alpha);
	}

	ALBEDO = wall_color.rgb;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA = painted_alpha * wall_color.a;
}
