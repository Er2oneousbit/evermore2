// =============================================================================
// color_grade.gdshader  -  Full-screen mood: grade, light shafts, vignette
// -----------------------------------------------------------------------------
// WHAT:  The "modern" finishing pass over the world (HUD is NOT graded):
//          1. saturation + contrast
//          2. split toning: tint the shadows (e.g. violet) and the highlights
//             (e.g. warm gold), the classic golden-hour film look
//          3. soft diagonal light shafts drifting slowly (sun through trees)
//          4. vignette, measured against a 16:9 frame around the center so
//             ultrawide screens darken their far edges instead of everything
//          5. drifting cloud shadows, anchored to the WORLD (they slide over
//             the ground as you walk, instead of sticking to the screen)
// WHO SETS IT: systems/atmosphere/atmosphere.gd (per time of day, tweened).
//        Every uniform is safe to tweak live in the editor.
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with <3 from your friendly hacker - er2oneousbit
// =============================================================================
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float contrast : hint_range(0.5, 1.5) = 1.0;
// rgb = color, a = strength. Added to dark areas.
uniform vec4 shadow_tint : source_color = vec4(0.0, 0.0, 0.0, 0.0);
// rgb = color, a = strength. Multiplied into bright areas.
uniform vec4 highlight_tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float shaft_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shaft_color : source_color = vec4(1.0, 0.85, 0.55, 1.0);
// How steeply the shafts slant (x per y).
uniform float shaft_slant = 0.55;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec4 vignette_color : source_color = vec4(0.05, 0.02, 0.1, 1.0);
// Cloud shadows: strength 0 = off. cam_px = world position of the screen's
// top-left pixel (Atmosphere sets it every frame).
uniform float cloud_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cloud_color : source_color = vec4(0.12, 0.1, 0.25, 1.0);
uniform sampler2D cloud_noise : repeat_enable, filter_linear;
uniform float cloud_scale = 900.0;
uniform vec2 cloud_wind = vec2(9.0, 3.0);
uniform vec2 cam_px = vec2(0.0);
// Visible game area in base pixels (Atmosphere keeps this in sync with
// ScreenScaler) so shafts and the vignette keep their shape on any monitor.
uniform vec2 view_px = vec2(640.0, 360.0);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));

	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c += shadow_tint.rgb * shadow_tint.a * (1.0 - smoothstep(0.0, 0.55, l));
	c = mix(c, c * highlight_tint.rgb, smoothstep(0.35, 1.0, l) * highlight_tint.a);

	// Light shafts: two slow sine bands multiplied = irregular soft beams,
	// brighter near the top of the screen where the light comes in.
	vec2 px = SCREEN_UV * view_px;
	float k = px.x - px.y * shaft_slant;
	float bands = (sin(k * 0.019 + TIME * 0.07) * 0.5 + 0.5) * (sin(k * 0.0071 - TIME * 0.045 + 1.3) * 0.5 + 0.5);
	bands = smoothstep(0.3, 0.9, bands);
	float fall = 1.0 - smoothstep(0.0, 1.1, SCREEN_UV.y);
	c += shaft_color.rgb * bands * fall * shaft_strength * 0.32;

	// Cloud shadows: low-frequency noise in world space, drifting with the wind.
	vec2 world = floor(cam_px + px) + cloud_wind * TIME;
	float n = texture(cloud_noise, world / cloud_scale).r;
	float shade = smoothstep(0.5, 0.68, n) * cloud_strength;
	c = mix(c, c * cloud_color.rgb * 2.2, shade);

	vec2 d = (px - view_px * 0.5) / vec2(view_px.y * 0.5 * 16.0 / 9.0, view_px.y * 0.5);
	float v = smoothstep(0.6, 1.45, length(d));
	c = mix(c, vignette_color.rgb, clamp(v * vignette_strength, 0.0, 0.8));

	COLOR = vec4(c, 1.0);
}
