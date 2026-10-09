// =============================================================================
// texel_aa.gdshaderinc  -  Sharp-bilinear ("fat pixel") texel lookup, shared
// -----------------------------------------------------------------------------
// WHAT:  texel_aa_uv(uv, tex_size) remaps a UV so a LINEAR sample returns the
//        flat colour of the texel under it, blended with its neighbour only in
//        a band about 0.6 of a screen pixel wide at the texel edge.
// WHY:   Plain NEAREST sampling of pixel art on a perspective 3D surface
//        gives each texel row 3 or 4 screen pixels depending on the frame, so
//        planks and rails crawl and change thickness as the camera drifts by
//        sub-pixels (owner, 2026-10-09: "the shop front glitching"). Edges
//        antialiased over one pixel move smoothly instead, and the texel
//        interiors stay crisp (no blur, unlike plain bilinear).
// HOW:   #include this file and call it from fragment() with textureSize().
//        The sampler must be filter_linear. The result stays inside the
//        texel's own cell, so an atlas frame never bleeds into the next one
//        except in that one-pixel edge band.
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with <3 from your friendly hacker - er2oneousbit
// =============================================================================
vec2 texel_aa_uv(vec2 uv, vec2 tex_size) {
	vec2 px = uv * tex_size;
	// 0.6 of a pixel: a full pixel looked soft on small texels (owner needs it crisp).
	vec2 fw = max(fwidth(px) * 0.6, vec2(1e-4));
	vec2 f = fract(px);
	return (floor(px) + 0.5 + clamp((f - 0.5) / fw, -0.5, 0.5)) / tex_size;
}
