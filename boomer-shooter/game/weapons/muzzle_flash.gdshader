shader_type spatial;
render_mode cull_disabled;

uniform sampler2D texture_noise;
instance uniform float ttl : hint_range(0.0, 1.0) = 0.0;
instance uniform float rand;

vec2 rotate_uv(vec2 uv, float angle) {
    uv -= vec2(0.5);
    float s = sin(angle);
    float c = cos(angle);
    uv = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
    return uv + vec2(0.5);
}

float random(vec2 uv) 
{
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453 + 
                 cos(dot(uv, vec2(4.898, 7.23))) * 23421.631) + 0.5;
}

void fragment() 
{
	vec2 base_uv = UV;
	base_uv = rotate_uv(base_uv, rand);

	float r = texture(texture_noise, base_uv + random(vec2(rand))).r;
	
	vec2 delta = base_uv - vec2(0.5);
	float angle_rad = atan(delta.y, delta.x);
	

	float distance_to_center = distance(base_uv, vec2(0.5)) * 2.0;
	float outter_distance = distance_to_center;
	outter_distance = 1.0 - outter_distance - ttl - (pow(r, 5.0)) + sin(angle_rad * 8.0) * 0.15;
	outter_distance = clamp(outter_distance, 0.0, 1.0);
	outter_distance = round(outter_distance);

	ALBEDO = vec3(1.0, 1.0, 0.0);
	EMISSION = ALBEDO;

	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;


	ALPHA = clamp(outter_distance, 0.0, 1.0) * 0.9;
}
