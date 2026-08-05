shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo : source_color, repeat_disable;
instance uniform vec3 modulate : source_color = vec3(1.0);
instance uniform float opening_enabled = 0.0;
instance uniform vec4 opening_rect = vec4(0.0);
instance uniform float editor_wall_base_only = 0.0;
uniform sampler2D texture_aoe : source_color;
uniform float metalic : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;

group_uniforms variation;
uniform float random_hue : hint_range(0.0, 1.0) = 0.0;
group_uniforms;

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

group_uniforms distortion;
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

group_uniforms blood;
uniform sampler2D blood_splats : filter_nearest, repeat_disable;
uniform int blood_splat_count = 0;
uniform sampler2D blood_noise_texture : filter_linear_mipmap, repeat_enable;
uniform vec2 blood_uv_size = vec2(0.3, 0.3);
uniform vec4 blood_color : source_color = vec4(0.9, 0.005, 0.008, 0.9);
group_uniforms;

uniform float contact_height = -999.0;
uniform vec2 contact_amp = vec2(0.0);

varying vec2 local_surface_position;
varying float node_random_seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float hash_position(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453123);
}

vec3 rgb_to_hsv(vec3 color) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(
		vec4(color.bg, k.wz),
		vec4(color.gb, k.xy),
		step(color.b, color.g));
	vec4 q = mix(
		vec4(p.xyw, color.r),
		vec4(color.r, p.yzx),
		step(p.x, color.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(
		abs(q.z + (q.w - q.y) / (6.0 * d + e)),
		d / (q.x + e),
		q.x);
}

vec3 hsv_to_rgb(vec3 color) {
	vec3 p = abs(fract(color.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return color.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), color.y);
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
		float half_tile_width = 0.5 / max(size.x, 0.0001);
		row += mod(info.idx.y, 2.0) * half_tile_width;
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

float get_blood_mask(vec2 uv, bool front_facing) {
	float painted_blood = 0.0;
	ivec2 blood_texture_size = textureSize(blood_splats, 0);
	vec2 chunk_size = max(wall_chunk_size, vec2(0.0001));
	float chunk_min_dimension = min(chunk_size.x, chunk_size.y);
	vec2 chunk_aspect = chunk_size / chunk_min_dimension;

	for (int splat_index = 0; splat_index < blood_splat_count; splat_index++) {
		ivec2 splat_pixel = ivec2(
			splat_index % blood_texture_size.x,
			 splat_index / blood_texture_size.x);
		vec4 splat_data = texelFetch(blood_splats, splat_pixel, 0);
		float splat_side = step(0.5, splat_data.b);
		float rendered_side = front_facing ? 1.0 : 0.0;
		if (abs(splat_side - rendered_side) > 0.5) {
			continue;
		}
		float splat_seed = fract(splat_data.b * 2.0);
		float size_scale = mix(0.7, 1.35, splat_data.a);
		vec2 splat_uv = (
			(uv - splat_data.rg) * chunk_aspect
			/ (blood_uv_size * size_scale));
		float rotation = splat_seed * TAU;
		float sin_theta = sin(rotation);
		float cos_theta = cos(rotation);
		splat_uv = vec2(
			cos_theta * splat_uv.x - sin_theta * splat_uv.y,
			sin_theta * splat_uv.x + cos_theta * splat_uv.y);

		float radius = length(splat_uv);
		vec2 blood_noise_uv = (
			splat_uv * 1.75
			+ vec2(splat_seed * 17.0, splat_seed * 31.0));
		float edge_noise = texture(blood_noise_texture, blood_noise_uv).r;
		float noisy_edge = 0.47 + (edge_noise - 0.5) * 0.22;
		float splat = 1.0 - smoothstep(
			noisy_edge - 0.07,
			noisy_edge + 0.04,
			radius);
		painted_blood = max(painted_blood, splat);
	}

	return painted_blood;
}

void vertex() {
	local_surface_position = VERTEX.xz;
	node_random_seed = hash_position(NODE_POSITION_WORLD);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}

	vec2 boundary_uv = UV;
	float height_from_bottom = 1.0 - boundary_uv.y;
	if (editor_wall_base_only > 0.5 && height_from_bottom > 0.5) {
		discard;
	}
	if (
		opening_enabled > 0.5
		&& boundary_uv.x >= opening_rect.x
		&& boundary_uv.x <= opening_rect.x + opening_rect.z
		&& boundary_uv.y >= opening_rect.y
		&& boundary_uv.y <= opening_rect.y + opening_rect.w
	) {
		discard;
	}
	vec2 surface_uv = local_surface_position;
	vec2 procedural_uv = surface_uv;
	procedural_uv += (texture(disorder, surface_uv).r * 2.0 - 1.0) * 0.001;

	vec3 aoe_color = texture(texture_aoe, boundary_uv).rgb;
	ALBEDO = texture(albedo, vec2(boundary_uv.x, 1.0 - boundary_uv.y)).rgb;

	vec4 color_detail = texture(texture_detail, boundary_uv * detail_uv_scale);
	ALBEDO = mix(ALBEDO, color_detail.rgb, detail * color_detail.a);

	METALLIC = metalic;
	ROUGHNESS = roughness;
	SPECULAR = specular;

	vec2 quad_edge_dist = min(boundary_uv, vec2(1.0) - boundary_uv);
	float quad_outline_noise = (texture(disorder, surface_uv * quad_outline_distortion_scale).r * 2.0 - 1.0) * quad_outline_distortion;
	vec2 quad_outline_width_distorted = max(quad_outline_width + vec2(quad_outline_noise), vec2(0.0));
	float quad_outline_x = 1.0 - step(quad_outline_width_distorted.x, quad_edge_dist.x);
	float quad_outline_y = 1.0 - step(quad_outline_width_distorted.y, quad_edge_dist.y);
	float quad_outline = max(quad_outline_x, quad_outline_y);
	ALBEDO = mix(ALBEDO, quad_outline_color.rgb, quad_outline * quad_outline_color.a);

	if (length(tile_size) > 0.0) {
		tile_info info = make_tile_info(procedural_uv, vec2(0.0), tile_size);
		vec2 edge_dist = min(info.coord_in_tile, vec2(1.0) - info.coord_in_tile);
		float outline_noise = (texture(disorder, surface_uv * tile_size * tile_outline_distortion_scale).r * 2.0 - 1.0) * tile_outline_distortion;
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

	ALBEDO *= modulate;

	vec3 hsv = rgb_to_hsv(ALBEDO);
	float signed_hue_seed = node_random_seed * 2.0 - 1.0;
	hsv.x = fract(hsv.x + signed_hue_seed * random_hue * 0.5);
	ALBEDO = hsv_to_rgb(hsv);
	float blood_mask = get_blood_mask(boundary_uv, FRONT_FACING);
	ALBEDO = mix(ALBEDO, blood_color.rgb, blood_mask * blood_color.a);
	ROUGHNESS = mix(ROUGHNESS, 0.72, blood_mask);

	AO = aoe_color.r;

	float contact_noise = noise_from_uv(surface_uv * contact_amp) * 0.1;
	float contact_alpha = round(boundary_uv.y + (0.5 - contact_height) + contact_noise);
	float bullet_hole_alpha = get_bullet_hole_alpha(boundary_uv);
	float broken_edge_alpha = get_broken_edge_alpha(boundary_uv);
	float detail_alpha = mix(1.0, color_detail.a, detail);

	ALPHA = min(detail_alpha, min(contact_alpha, min(bullet_hole_alpha, broken_edge_alpha)));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
