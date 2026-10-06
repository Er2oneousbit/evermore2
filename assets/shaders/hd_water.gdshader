// =============================================================================
// hd_water.gdshader  -  Reflective pond surface for the HD-2D view
// -----------------------------------------------------------------------------
// WHAT:  A plane laid over the whole baked ground. Wherever the baked pixel is
//        WATER (LPC water is teal/blue), it becomes a glossy, rippling surface:
//          - the LPC water art stays as the base color (pixel art preserved),
//            part lit by the scene, part self-glowing (self_glow) so it keeps
//            its teal in any light
//          - very low roughness, so screen-space reflections show trees, the
//            kid and the sky mirrored in the pond (Forward+ only)
//          - two scrolling noise normal maps = ripples and sun glints
//        Everywhere else the pixel is discarded and the ground shows through.
// NEEDS: ground_tex = the baked ground texture (same size/position as the
//        ground plane), ripple_noise = a seamless NoiseTexture2D (normal map).
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with <3 from your friendly hacker - er2oneousbit
// =============================================================================
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform sampler2D ground_tex : source_color, filter_nearest;
uniform sampler2D ripple_noise : hint_normal, repeat_enable, filter_linear;
uniform vec4 tint : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float ripple_scale = 0.18;
uniform float ripple_speed = 0.03;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.35;
uniform float gloss : hint_range(0.0, 1.0) = 0.96;
// How much of the water's color it "glows" on its own (0 = fully lit by scene).
uniform float self_glow : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 g = texture(ground_tex, UV).rgb;
	// Same "is this water?" test as the 2D shimmer shader.
	float water = smoothstep(0.0, 0.06, g.b - g.g * 0.88 - g.r * 0.12);
	if (water < 0.5) {
		discard;
	}
	ALBEDO = g * tint.rgb * 0.8;
	EMISSION = g * self_glow;
	ROUGHNESS = 1.0 - gloss;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	vec2 p = world_pos.xz * ripple_scale;
	vec3 n1 = texture(ripple_noise, p + vec2(TIME * ripple_speed, TIME * ripple_speed * 0.6)).rgb;
	vec3 n2 = texture(ripple_noise, p * 1.7 - vec2(TIME * ripple_speed * 0.7, -TIME * ripple_speed)).rgb;
	NORMAL_MAP = normalize(mix(vec3(0.5, 0.5, 1.0), (n1 + n2) * 0.5, ripple_strength));
}
