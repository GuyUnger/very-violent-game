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

uniform float contact_height = -999.0;
uniform vec2 contact_amp = vec2(0.0);

varying vec3 aabb_factor;

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise_from_uv(vec2 uv)
{
    vec2 i = floor(uv);
    vec2 f = fract(uv);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float random(vec2 st)
{
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

struct tile_info
{
	vec2 idx;
	float island_random;
	float is_line;
	vec2 coord_in_tile;
};

tile_info make_tile_info(vec2 uv, vec2 offset, vec2 size)
{
	tile_info info;

	// todo add this back
	vec2 noise_tex_1 = vec2(0.0);

	float row = uv.x + noise_tex_1.r + offset.x;
	float col = uv.y + noise_tex_1.r + offset.y;

	info.idx = vec2(floor(row * size.x), floor(col * size.y));

	row = uv.x;
	if(tile_bricks) row += random(vec2(info.idx.y));
	row += noise_tex_1.r;
	info.idx.x = floor(row * tile_size.x);

	info.island_random = mod(random(info.idx + offset), 1.0);

	vec2 tile_seam_thickness_with_noise = tile_seam_thickness + noise_tex_1.r;

	info.coord_in_tile.x = mod(row * size.x , 1.0);
	info.coord_in_tile.y = mod(col * size.y, 1.0);

	info.is_line = 0.0;
	info.is_line += step(mod(info.coord_in_tile.x + tile_seam_thickness_with_noise.x * 0.5, 1.0), tile_seam_thickness_with_noise.x);
	info.is_line += step(mod(info.coord_in_tile.y + tile_seam_thickness_with_noise.y * 0.5, 1.0), tile_seam_thickness_with_noise.y);
	info.is_line = clamp(info.is_line, 0.0, 1.0);

	return info;
}

void vertex()
{
	aabb_factor = VERTEX / aabb;
	aabb_factor.xz += aabb.xz * 0.5;
}

void fragment()
{
	vec2 base_uv = UV;
	base_uv += (texture(disorder, base_uv).r * 2.0 - 1.0) * 0.001;
	
	vec3 aoe_color = texture(texture_aoe, base_uv).rgb;

	ALBEDO = texture(albedo, vec2(aabb_factor.x, 1.0 - aabb_factor.y)).rgb;



	vec4 color_detail = texture(texture_detail, UV * detail_uv_scale);
	color_detail.a -= wear;
	color_detail.a  = clamp(color_detail.a, 0.0, 1.0);
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

	if(length(tile_size) > 0.0)
	{
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
		ALBEDO =  mix(ALBEDO, ALBEDO * 0.50, info.island_random * tile_variance);
		ALBEDO = mix(ALBEDO, ALBEDO * tile_modulate.rgb, tile_modulate.a * info.is_line);
	}

	float w = aoe_color.g;
	w = clamp(round(w * wear), 0.0, 1.0);
	ALBEDO = mix(ALBEDO, ALBEDO * wear_multiply, w);

	ALBEDO *= modulate;

	AO = aoe_color.r;

	float r = noise_from_uv(aabb_factor.xy * contact_amp) * 0.1;
	ALPHA = round(aabb_factor.y + (0.5 - contact_height) + r);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
