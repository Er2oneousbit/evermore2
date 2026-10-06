// =============================================================================
// water_shimmer.gdshader  -  Living water on top of static water tiles
// -----------------------------------------------------------------------------
// WHAT:  Adds slowly drifting light ripples, a sky-colored sheen, and tiny
//        sparkles that pop in and out, all in WORLD space (so they flow
//        across tile seams instead of repeating per tile).
// WHERE: The material of the water TileMapLayer. It never moves UVs, so it is
//        safe on tilemaps (no bleeding from neighboring atlas tiles).
// NEEDS: `noise` = a seamless NoiseTexture2D (water_noise.tres).
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with <3 from your friendly hacker - er2oneousbit
// =============================================================================
shader_type canvas_item;

uniform sampler2D noise : repeat_enable, filter_linear;
// Tint mixed in on the brightest ripples (reflected sky).
uniform vec4 sheen_color : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.22;
// World pixels per noise repeat. Bigger = broader ripples.
uniform float ripple_scale = 220.0;
uniform float ripple_speed = 0.035;
// 0 = no sparkles. 0.97 = a few. 0.9 = lots.
uniform float sparkle_threshold : hint_range(0.8, 1.0) = 0.955;
uniform vec4 sparkle_color : source_color = vec4(1.0, 0.97, 0.85, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = COLOR;
	// Only touch WATER pixels: shore tiles also contain grass and dirt.
	// LPC water is teal/blue (blue above green and red); grass and dirt aren't.
	float water = smoothstep(0.0, 0.06, base.b - base.g * 0.88 - base.r * 0.12);
	// Snap to whole world pixels so the effect stays pixel-crisp.
	vec2 p = floor(world_pos) / ripple_scale;
	float a = texture(noise, p + vec2(TIME * ripple_speed, TIME * ripple_speed * 0.4)).r;
	float b = texture(noise, p * 1.7 - vec2(TIME * ripple_speed * 0.8, -TIME * ripple_speed * 0.6)).r;
	float ripple = smoothstep(0.55, 0.85, (a + b) * 0.5);
	base.rgb = mix(base.rgb, sheen_color.rgb, ripple * sheen_strength * water);
	// Sparkles: a fine noise sample that only crosses the threshold briefly.
	float s = texture(noise, floor(world_pos) / 23.0 + vec2(TIME * 0.11, -TIME * 0.07)).r;
	float sparkle = step(sparkle_threshold, s) * step(0.5, a) * step(0.5, water);
	base.rgb = mix(base.rgb, sparkle_color.rgb, sparkle * base.a);
	COLOR = base;
}
