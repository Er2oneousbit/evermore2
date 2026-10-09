// =============================================================================
// hd_actor_ground.gdshader  -  hd_actor, for art that reaches below the feet
// -----------------------------------------------------------------------------
// WHAT:  The same lighting as hd_actor.gdshader, plus one thing: a fragment
//        that lies below the ground plane keeps its screen position but gets
//        the depth it would have at ground level, so it draws over the ground
//        instead of being cut off by it.
// WHY:   The kid's club is drawn on a 192 px frame and swings ~11 px below his
//        soles. In HD-2D the quad stands upright, so that part of the club was
//        under the ground plane and its tip vanished mid-swing.
// WHO SETS IT: systems/hd2d/hd_view.gd, for the actor layers listed in an
//        actor's "hd_layers" meta (the weapon layers). Bodies keep hd_actor,
//        because a shader that writes depth in the shadow pass breaks shadows;
//        so these layers don't cast one.
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with <3 from your friendly hacker - er2oneousbit
// =============================================================================
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://assets/shaders/texel_aa.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform float lift : hint_range(0.0, 1.0) = 0.1;

// Just above the ground, not on it: equal depths would z-fight the ground.
const float LIFT = 0.12;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = texture(tex, texel_aa_uv(UV, vec2(textureSize(tex, 0)))) * COLOR;
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	EMISSION = c.rgb * lift;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(0.0, 0.8, 0.6)), 0.0)).xyz);
	// Below the ground? Slide the point up its view ray to y = 0: same pixel,
	// ground-level depth. DEPTH is always written (unwritten = garbage).
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 p = world_pos;
	if (p.y < LIFT) {
		p = cam + (p - cam) * ((cam.y - LIFT) / (cam.y - p.y));
	}
	vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(p, 1.0));
	DEPTH = clip.z / clip.w;
}
