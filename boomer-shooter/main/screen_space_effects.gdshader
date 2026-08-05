shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D mist_noise_texture : repeat_enable, filter_linear;

// Kept deliberately subtle at the centre, increasing toward the screen edge.
uniform float chromatic_aberration : hint_range(0.0, 0.02, 0.0001) = 0.002;
uniform float damage_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 damage_color : source_color = vec4(0.65, 0.005, 0.01, 1.0);

void fragment() {
	vec2 from_centre = UV - vec2(0.5);
	float centre_distance = length(from_centre) / length(vec2(0.5));
	float edge_amount = smoothstep(0.25, 1.0, centre_distance);
	vec2 direction = length(from_centre) > 0.0001 ? normalize(from_centre) : vec2(0.0);
	vec2 channel_offset = direction * chromatic_aberration * edge_amount * edge_amount;

	vec3 screen_colour;
	screen_colour.r = texture(screen_texture, SCREEN_UV + channel_offset).r;
	screen_colour.g = texture(screen_texture, SCREEN_UV).g;
	screen_colour.b = texture(screen_texture, SCREEN_UV - channel_offset).b;

	float closest_edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float mist_edge = 1.0 - smoothstep(0.0, 0.32, closest_edge);
	vec2 noise_motion = vec2(TIME * 0.012, -TIME * 0.008);
	float mist_noise = texture(
		mist_noise_texture,
		UV * vec2(1.75, 1.25) + noise_motion
	).r;
	mist_noise = mix(
		mist_noise,
		texture(mist_noise_texture, UV * 3.25 - noise_motion * 0.6).r,
		0.35
	);
	float mist = mist_edge * smoothstep(0.18, 0.82, mist_noise + mist_edge * 0.35);
	float mist_alpha_pulse = 0.75 + sin(TIME * 16.0) * 0.25;
	mist *= damage_intensity * damage_color.a * mist_alpha_pulse;

	COLOR = vec4(mix(screen_colour, damage_color.rgb, mist), 1.0);
}
