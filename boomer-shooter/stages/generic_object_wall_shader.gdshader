shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo : source_color, repeat_disable;
uniform vec3 modulate : source_color = vec3(1.0);
uniform sampler2D texture_aoe : source_color;
uniform float metalic : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform vec3 aabb = vec3(1.0);

group_uniforms detail;
uniform float detail : hint_range(0.0, 1.0);
uniform sampler2D texture_detail : source_color;
uniform vec2 detail_uv_scale = vec2(1.0, 1.0);
group_uniforms;

group_uniforms tile;
uniform vec2 tile_size;
uniform bool tile_bricks = true;
uniform vec2 tile_seam_thickness;
uniform vec2 tile_outline_width = vec2(0.0);
uniform vec4 tile_outline_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float tile_outline_distortion : hint_range(0.0, 1.0) = 0.0;
uniform vec2 tile_outline_distortion_scale = vec2(1.0, 1.0);
uniform vec4 tile_modulate : source_color;
uniform float tile_variance = 1.0;
group_uniforms;

group_uniforms outline;
uniform vec2 quad_outline_width = vec2(0.0, 0.0);
uniform vec4 quad_outline_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float quad_outline_distortion : hint_range(0.0, 1.0) = 0.0;
uniform vec2 quad_outline_distortion_scale = vec2(1.0, 1.0);
group_uniforms;

group_uniforms wear;
uniform float wear;
uniform float wear_multiply;
uniform sampler2D disorder;
group_uniforms;

group_uniforms wall_hits;
uniform sampler2D holes : filter_nearest, repeat_disable;
uniform int hole_count = 0;
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
group_uniforms;

uniform float contact_height = -999.0;
uniform vec2 contact_amp = vec2(0.0);

varying vec3 aabb_factor;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise_from_uv(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float random(vec2 st) {
	return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

struct tile_info {
	vec2 idx;
	float island_random;
	float is_line;
	vec2 coord_in_tile;
};

tile_info make_tile_info(vec2 uv, vec2 offset, vec2 size) {
	tile_info info;

	vec2 noise_tex_1 = vec2(0.0);

	float row = uv.x + noise_tex_1.r + offset.x;
	float col = uv.y + noise_tex_1.r + offset.y;

	info.idx = vec2(floor(row * size.x), floor(col * size.y));

	row = uv.x;
	if (tile_bricks) {
		row += random(vec2(info.idx.y));
	}
	row += noise_tex_1.r;
	info.idx.x = floor(row * tile_size.x);

	info.island_random = mod(random(info.idx + offset), 1.0);

	vec2 tile_seam_thickness_with_noise = tile_seam_thickness + noise_tex_1.r;

	info.coord_in_tile.x = mod(row * size.x, 1.0);
	info.coord_in_tile.y = mod(col * size.y, 1.0);

	info.is_line = 0.0;
	info.is_line += step(mod(info.coord_in_tile.x + tile_seam_thickness_with_noise.x * 0.5, 1.0), tile_seam_thickness_with_noise.x);
	info.is_line += step(mod(info.coord_in_tile.y + tile_seam_thickness_with_noise.y * 0.5, 1.0), tile_seam_thickness_with_noise.y);
	info.is_line = clamp(info.is_line, 0.0, 1.0);

	return info;
}

float get_bullet_hole_alpha(vec2 uv) {
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
		vec2 local_uv = ((uv - hit_data.rg) * chunk_aspect) / (hole_uv_size * hole_size_scale);
		float sin_theta = sin(rotation);
		float cos_theta = cos(rotation);
		vec2 hole_uv = vec2(
			cos_theta * local_uv.x - sin_theta * local_uv.y,
			sin_theta * local_uv.x + cos_theta * local_uv.y) + vec2(0.5);
		if (any(lessThan(hole_uv, vec2(0.0))) || any(greaterThan(hole_uv, vec2(1.0)))) {
			continue;
		}

		int atlas_index = (hit_index * 73 + 19) % atlas_tile_count;
		ivec2 atlas_tile = ivec2(
			atlas_index % atlas_grid.x,
			atlas_index / atlas_grid.x);
		vec2 atlas_uv = (vec2(atlas_tile) + hole_uv) / vec2(atlas_grid);
		vec3 hole_sample = texture(hole_atlas, atlas_uv).rgb;

		if (all(greaterThanEqual(hole_sample, vec3(0.999)))) {
			continue;
		}

		float hole_alpha = dot(hole_sample, vec3(0.299, 0.587, 0.114));
		painted_alpha = min(painted_alpha, hole_alpha);
	}

	return painted_alpha;
}

float get_broken_edge_alpha(vec2 uv) {
	if (broken <= 0.5) {
		return 1.0;
	}

	vec2 chunk_size = max(wall_chunk_size, vec2(0.0001));
	float chunk_min_dimension = min(chunk_size.x, chunk_size.y);
	vec2 chunk_aspect = chunk_size / chunk_min_dimension;
	vec2 edge_distance_uv = min(uv, vec2(1.0) - uv) * chunk_aspect;
	float edge_distance = min(edge_distance_uv.x, edge_distance_uv.y);
	float edge_band = max(break_edge_width, 0.0001);
	float noise_value = texture(edge_noise_texture, uv * edge_noise_scale * chunk_aspect).r;
	float jagged_cutoff = clamp(
		break_edge_width - noise_value * edge_noise_strength,
		0.0,
		break_edge_width);
	return 1.0 - smoothstep(
		jagged_cutoff,
		jagged_cutoff + edge_band * 0.35,
		edge_distance);
}

void vertex() {
	aabb_factor = VERTEX / aabb;
	aabb_factor.xz += aabb.xz * 0.5;
}

void fragment() {
	vec2 base_uv = UV;
	base_uv += (texture(disorder, base_uv).r * 2.0 - 1.0) * 0.001;

	vec3 aoe_color = texture(texture_aoe, base_uv).rgb;
	ALBEDO = texture(albedo, vec2(aabb_factor.x, 1.0 - aabb_factor.y)).rgb;

	vec4 color_detail = texture(texture_detail, UV * detail_uv_scale);
	color_detail.a -= wear;
	color_detail.a = clamp(color_detail.a, 0.0, 1.0);
	ALBEDO = mix(ALBEDO, color_detail.rgb, detail * color_detail.a);

	METALLIC = metalic;
	ROUGHNESS = roughness;
	SPECULAR = specular;

	vec2 quad_edge_dist = min(UV, vec2(1.0) - UV);
	float quad_outline_noise = (texture(disorder, base_uv * quad_outline_distortion_scale).r * 2.0 - 1.0) * quad_outline_distortion;
	vec2 quad_outline_width_distorted = max(quad_outline_width + vec2(quad_outline_noise), vec2(0.0));
	float quad_outline_x = 1.0 - step(quad_outline_width_distorted.x, quad_edge_dist.x);
	float quad_outline_y = 1.0 - step(quad_outline_width_distorted.y, quad_edge_dist.y);
	float quad_outline = max(quad_outline_x, quad_outline_y);
	ALBEDO = mix(ALBEDO, quad_outline_color.rgb, quad_outline * quad_outline_color.a);

	if (length(tile_size) > 0.0) {
		tile_info info = make_tile_info(base_uv, vec2(0.0), tile_size);
		vec2 edge_dist = min(info.coord_in_tile, vec2(1.0) - info.coord_in_tile);
		float outline_noise = (texture(disorder, base_uv * tile_size * tile_outline_distortion_scale).r * 2.0 - 1.0) * tile_outline_distortion;
		vec2 outline_width = max(tile_outline_width + vec2(outline_noise), vec2(0.0));
		float outline_x = 1.0 - step(outline_width.x, edge_dist.x);
		float outline_y = 1.0 - step(outline_width.y, edge_dist.y);
		float outline = max(outline_x, outline_y);
		ALBEDO = mix(ALBEDO, ALBEDO * 0.5, info.is_line);
		ALBEDO = mix(ALBEDO, tile_outline_color.rgb, outline * tile_outline_color.a);
		ROUGHNESS += info.is_line;
		SPECULAR -= info.is_line;
		SPECULAR = clamp(SPECULAR, 0.0, 1.0);
		ROUGHNESS = clamp(ROUGHNESS, 0.0, 1.0);
		ALBEDO = mix(ALBEDO, ALBEDO * 0.50, info.island_random * tile_variance);
		ALBEDO = mix(ALBEDO, ALBEDO * tile_modulate.rgb, tile_modulate.a * info.is_line);
	}

	float w = clamp(round(aoe_color.g * wear), 0.0, 1.0);
	ALBEDO = mix(ALBEDO, ALBEDO * wear_multiply, w);
	ALBEDO *= modulate;

	AO = aoe_color.r;

	float contact_noise = noise_from_uv(aabb_factor.xy * contact_amp) * 0.1;
	float contact_alpha = round(aabb_factor.y + (0.5 - contact_height) + contact_noise);
	float bullet_hole_alpha = get_bullet_hole_alpha(UV);
	float broken_edge_alpha = get_broken_edge_alpha(UV);
	float detail_alpha = mix(1.0, color_detail.a, detail);

	ALPHA = min(detail_alpha, min(contact_alpha, min(bullet_hole_alpha, broken_edge_alpha)));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
