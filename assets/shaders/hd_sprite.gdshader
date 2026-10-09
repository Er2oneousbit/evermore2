// =============================================================================
// hd_sprite.gdshader  -  Pixel-art props standing in the HD-2D 3D world
// -----------------------------------------------------------------------------
// WHAT:  Draws one frame of a sprite on an upright quad (trees, bushes, rocks,
//        reeds) or a flat one (lily pads), lit by the 3D sun and lights:
//          - nearest-neighbor pixels, hard alpha cutout (so it casts proper
//            tree-shaped sun shadows and writes depth: no sorting problems)
//          - wind sway that shifts whole texel rows (pixels never smear)
//          - multi-frame animation computed here from TIME (no CPU per frame),
//            each copy offset by its world position so they don't sync up
//          - lighting normal tilted up toward the camera, so a sprite facing
//            the camera is lit like the ground it stands on (the HD-2D look)
// WHO SETS IT: systems/hd2d/hd_view.gd builds one material per prop type.
// NOTE:  "flat" is a reserved word in Godot shaders, hence lying_flat.
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with <3 from your friendly hacker - er2oneousbit
// =============================================================================
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D tex : source_color, filter_nearest;
// One frame's rect inside the texture, in UV: (x, y, w, h).
uniform vec4 frame_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 texel = vec2(0.01, 0.01);
uniform float frames = 1.0;
uniform float fps = 0.0;
// Wind sway: max texel shift at the top; 0 = rock solid.
uniform float sway_strength = 0.0;
uniform float sway_speed = 0.5;
uniform float rooted : hint_range(0.0, 1.0) = 0.4;
// Upright sprites get a normal leaning toward "up"; flat ones use straight up.
uniform bool lying_flat = false;
uniform float roughness_value = 0.92;

varying vec3 world_origin;

void vertex() {
	world_origin = NODE_POSITION_WORLD;
}

void fragment() {
	float phase = world_origin.x * 0.37 + world_origin.z * 0.23;
	float f = frames > 1.0 ? floor(mod(TIME * fps + phase, frames)) : 0.0;

	// 0 at the roots, 1 at the top (UV.y = 0 is the top of the quad).
	float h = clamp(((1.0 - UV.y) - rooted) / max(1.0 - rooted, 0.001), 0.0, 1.0);
	float t = TIME * sway_speed * 6.2831 + phase * 2.0;
	float sway = sin(t) * 0.75 + sin(t * 2.37 + 1.3) * 0.25;
	// Everything above the roots moves as one block. Scaling the shift by height
	// made the row where it rounds from 0 to 1 slide up and down the canopy as
	// the wind changed: a visible wipe (owner, 2026-10-09).
	float shift = round(sway * sway_strength * step(0.001, h));

	vec2 uv = vec2(frame_rect.x + (f + UV.x) * frame_rect.z - shift * texel.x,
			frame_rect.y + UV.y * frame_rect.w);
	float frame_left = frame_rect.x + f * frame_rect.z;
	if (uv.x < frame_left || uv.x > frame_left + frame_rect.z) {
		discard;
	}
	vec4 c = texture(tex, uv);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.2;
	vec3 n_world = lying_flat ? vec3(0.0, 1.0, 0.0) : normalize(vec3(0.0, 0.8, 0.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
}
