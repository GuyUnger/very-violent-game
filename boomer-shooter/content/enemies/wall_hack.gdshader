shader_type spatial;
render_mode depth_test_disabled, unshaded;

instance uniform vec4 color = vec4(0.0, 0.0, 0.0, 0.0);


void fragment() 
{
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
