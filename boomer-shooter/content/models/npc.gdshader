shader_type spatial;
render_mode cull_disabled;

instance uniform float damage_left_leg : hint_range(0.0, 1.0);
instance uniform float damage_right_leg : hint_range(0.0, 1.0);
instance uniform float damage_left_arm : hint_range(0.0, 1.0);
instance uniform float damage_right_arm : hint_range(0.0, 1.0);

instance uniform float hole_damage : hint_range(0.0, 1.0);

uniform sampler2D texture_holes;

uniform vec3 skin_color : source_color;
uniform vec3 blood_color : source_color;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() 
{
	ALBEDO = skin_color;
	
	float left_leg_factor = UV.x < 0.5 ? 1.0 : 0.0;
	left_leg_factor *= (UV.y - 0.5) * 2.0;
	left_leg_factor = clamp(left_leg_factor, 0.0, 1.0);
	
	float right_leg_factor = UV.x > 0.5 ? 1.0 : 0.0;
	right_leg_factor *= (UV.y - 0.5) * 2.0;
	right_leg_factor = clamp(right_leg_factor, 0.0, 1.0);
	
	float left_arm_factor = UV.x < 0.5 ? 1.0 : 0.0;
	left_arm_factor *= 1.0 - (UV.x * 2.0);
	left_arm_factor = clamp(left_arm_factor, 0.0, 1.0);
	
	float right_arm_factor = UV.x > 0.5 ? 1.0 : 0.0;
	right_arm_factor *= (UV.x - 0.5) * 2.0;
	right_arm_factor = clamp(right_arm_factor, 0.0, 1.0);
	

	ALPHA -= (damage_left_arm * left_arm_factor);
	ALPHA -= (damage_right_arm * right_arm_factor);
	ALPHA -= (damage_left_leg * left_leg_factor);
	ALPHA -= (damage_right_leg * right_leg_factor);
	
	float r = texture(texture_holes, UV).r;
	r *= hole_damage;
	
	ALPHA -= r;
	
	ALPHA = clamp(ALPHA, 0.0, 1.0);
	
	ALPHA_SCISSOR_THRESHOLD = 0.7;
	
	if(!FRONT_FACING)
	{
		ALBEDO = blood_color;
	}



}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
