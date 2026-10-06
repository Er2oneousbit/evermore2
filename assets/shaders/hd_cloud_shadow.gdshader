// =============================================================================
// hd_cloud_shadow.gdshader  -  Invisible clouds that only cast shadows
// -----------------------------------------------------------------------------
// WHAT:  A big plane high above the yard, drawn with cast_shadow = SHADOWS_ONLY.
//        Noise decides where the "cloud" is solid; the sun's shadow map turns
//        that into soft moving cloud shadows on the ground, and into breaks
//        in the volumetric fog (light shafts between clouds).
//        hd_view.gd slides the plane with the wind.
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with <3 from your friendly hacker - er2oneousbit
// =============================================================================
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D noise : repeat_enable, filter_linear;
// Fraction of the sky covered (0 = clear, 1 = overcast).
uniform float coverage : hint_range(0.0, 1.0) = 0.35;
// How many noise repeats across the plane (more = smaller clouds).
uniform float repeats = 4.0;

void fragment() {
	float n = texture(noise, UV * repeats).r;
	ALPHA = step(1.0 - coverage, n);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = vec3(1.0);
}
