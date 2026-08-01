// NOTE: Shader automatically converted from Godot Engine 4.4.beta4's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo : source_color;
uniform sampler2D texture_noise : source_color, filter_linear_mipmap, repeat_enable;
uniform float powderyness : hint_range(0.0, 1.0);

varying float instance_rand;

float rand(int seed) 
{
    return fract(sin(float(seed) * 12.9898) * 43758.5453);
}

void vertex() 
{
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			MAIN_CAM_INV_VIEW_MATRIX[0],
			MAIN_CAM_INV_VIEW_MATRIX[1],
			MAIN_CAM_INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]);

	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);

	instance_rand = rand(INSTANCE_ID);
}

void fragment() 
{
	ALBEDO = albedo;
	
	vec2 base_uv = UV;

	base_uv += instance_rand + TIME * 0.5;

	float noise = texture(texture_noise, base_uv).r;

	float distance_to_center = distance(UV, vec2(0.5, 0.5));
	distance_to_center = pow(distance_to_center, COLOR.a);

	ALPHA = 1.0 - distance_to_center;
	ALPHA -= noise * powderyness;

	ALPHA *= COLOR.a;
	
	ALPHA = clamp(ALPHA, 0.0, 1.0);
	
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
