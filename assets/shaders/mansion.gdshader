// =============================================================================
// mansion.gdshader  -  The Ruffleberg mansion's dark silhouette with moon rim light
// -----------------------------------------------------------------------------
// WHAT:  A lit pixel-art surface (world triplanar, 1 tile per meter, the same
//        sharp-bilinear lookup as hd_texel) tinted nearly black-blue, with an
//        emissive rim: edges seen at a grazing angle catch the moon behind the
//        house, and upward-facing surfaces (roof slopes) get a faint sheen.
// WHY:   The title shows the mansion far away, backlit by the moon. The night
//        sun lights the faces turned toward the camera, so a plain material
//        reads as a flat grey box; the rim keeps the outline readable and the
//        body dark. `textured = false` gives plain tinted surfaces (trees).
// HOW:   Built by systems/hd2d/mansion_building.gd. Tune `tint` for how dark
//        the house is and `rim_strength` for how much moon sits on its edges.
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with <3 from your friendly hacker - er2oneousbit
// =============================================================================
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://assets/shaders/texel_aa.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear, repeat_enable;
uniform bool textured = true;
uniform vec3 tint : source_color = vec3(0.2, 0.22, 0.32);
uniform vec3 rim_color : source_color = vec3(0.45, 0.58, 0.9);
uniform float rim_strength = 0.9;
uniform float roof_sheen = 0.07;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = vec3(1.0);
	if (textured) {
		vec3 p = wpos * vec3(1.0, -1.0, 1.0);
		vec3 a = abs(wnorm);
		vec2 uv;
		if (a.y >= a.x && a.y >= a.z) {
			uv = p.xz;
		} else if (a.x >= a.z) {
			uv = p.zy * vec2(-1.0, 1.0);
		} else {
			uv = p.xy;
		}
		vec2 ts = vec2(textureSize(tex, 0));
		col = texture(tex, texel_aa_uv(uv, ts)).rgb;
	}
	ALBEDO = col * tint;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	float edge = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 3.0);
	float up = clamp(wnorm.y, 0.0, 1.0);
	EMISSION = rim_color * (edge * rim_strength + up * roof_sheen);
}
