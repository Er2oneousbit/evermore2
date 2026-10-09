# =============================================================================
# texel_material.gd  -  Builds the shimmer-free pixel-art material
# -----------------------------------------------------------------------------
# WHAT:  TexelMaterial.make(tex, ...) returns a ShaderMaterial on
#        assets/shaders/hd_texel.gdshader: lit, linear-filtered, with the
#        sharp-bilinear texel lookup, optional world triplanar mapping, alpha
#        cut-out and an atlas slice (uv_scale / uv_offset).
# WHY:   Shops, fences, goods, signs and the ground used StandardMaterial3D
#        with NEAREST filtering, which crawls and flickers when the camera
#        moves by sub-pixels. One shared builder keeps them all consistent.
# HOW:   Call from HdView / ShopBuilding3D. smoke_hd checks every pixel-art
#        surface uses this shader.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name TexelMaterial
extends RefCounted

const SHADER := preload("res://assets/shaders/hd_texel.gdshader")


## `triplanar`: world-space, 1 tile per meter. `cutout`: alpha scissor.
## `uv_scale`/`uv_offset`: a slice of an atlas (ignored when triplanar).
static func make(tex: Texture2D, triplanar := false, cutout := false,
		uv_scale := Vector2.ONE, uv_offset := Vector2.ZERO, roughness := 0.9,
		specular := 0.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("triplanar", triplanar)
	m.set_shader_parameter("cutout", cutout)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("uv_offset", uv_offset)
	m.set_shader_parameter("roughness_value", roughness)
	m.set_shader_parameter("specular_value", specular)
	return m
