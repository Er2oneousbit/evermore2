// =============================================================================
// hd_texel.gdshader  -  Pixel-art surfaces in 3D: shops, fences, ground
// -----------------------------------------------------------------------------
// WHAT:  One lit material for everything pixel-art that isn't a sprite prop or
//        an actor: shop walls/roofs/counters (world triplanar, 1 tile per
//        meter), fence wood, goods and signs (cut-out quads, optional atlas
//        slice), and the baked ground plane (mesh UVs). All sampled with the
//        sharp-bilinear lookup in texel_aa.gdshaderinc, so texels stay crisp
//        but their edges move smoothly with the camera instead of shimmering.
// WHY:   StandardMaterial3D with NEAREST filtering crawled at 3440x1440.
// HOW:   Built by systems/hd2d/texel_material.gd. Lighting matches the old
//        StandardMaterial3D (burley diffuse, ggx specular, roughness 0.9).
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with <3 from your friendly hacker - er2oneousbit
// =============================================================================
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://assets/shaders/texel_aa.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear, repeat_enable;
uniform bool triplanar = false;
uniform bool cutout = false;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform float roughness_value = 0.9;
uniform float specular_value = 0.5;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv;
	if (triplanar) {
		// Same axis conventions as StandardMaterial3D world triplanar, but the
		// dominant face wins (no blend) so texels never double up.
		vec3 p = wpos * vec3(1.0, -1.0, 1.0);
		vec3 a = abs(wnorm);
		if (a.y >= a.x && a.y >= a.z) {
			uv = p.xz;
		} else if (a.x >= a.z) {
			uv = p.zy * vec2(-1.0, 1.0);
		} else {
			uv = p.xy;
		}
	} else {
		uv = UV * uv_scale + uv_offset;
	}
	vec2 ts = vec2(textureSize(tex, 0));
	vec2 auv = texel_aa_uv(uv, ts);
	if (!triplanar) {
		// No wrap-around: the edge tap would blend in the opposite side of the texture.
		auv = clamp(auv, 0.5 / ts, 1.0 - 0.5 / ts);
	}
	vec4 c = texture(tex, auv);
	ALBEDO = c.rgb;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	ALPHA = cutout ? c.a : 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
