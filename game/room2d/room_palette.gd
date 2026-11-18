class_name RoomPalette
extends RefCounted
## The occult palette for the shop room and the post shader that squeezes the 480x270 render into it:
## 16 colours (deep purples, sickly greens, candle amber, bone white, blood reds) and a 4x4 Bayer ordered dither.

const SIZE: int = 16
const HEX: Array[int] = [
	0x0b0710, 0x1c1030, 0x3a2455, 0x5c3d80, 0x8a6bb0,  # purples, dark to light
	0x20382a, 0x3f6b3a, 0x8fb04a,  # sickly greens
	0x4a2a1a, 0x8a5028, 0xd98a2b, 0xf2c15a,  # wood browns and candle ambers
	0x6e1a26, 0xc8363f,  # blood reds
	0xcfc6b0, 0xf5efe0,  # bone
]

const SHADER_HEAD: String = """shader_type canvas_item;
uniform bool dither_on = true;
uniform float dither_strength = 0.14;
uniform vec2 res = vec2(480.0, 270.0);
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
"""

const SHADER_BODY: String = """
void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	ivec2 p = ivec2(floor(UV * res));
	float t = (BAYER[(p.x & 3) + (p.y & 3) * 4] + 0.5) / 16.0 - 0.5;
	if (dither_on) {
		c += vec3(t * dither_strength);
	}
	vec3 best = PAL[0];
	float best_d = 1000.0;
	for (int i = 0; i < 16; i++) {
		vec3 d = (c - PAL[i]) * vec3(0.30, 0.59, 0.11) * 3.0;
		float dd = dot(d, d);
		if (dd < best_d) {
			best_d = dd;
			best = PAL[i];
		}
	}
	COLOR = vec4(best, 1.0);
}
"""


## The 16 palette colours (sRGB).
static func colors() -> PackedColorArray:
	var out := PackedColorArray()
	for h: int in HEX:
		out.append(Color.hex((h << 8) | 0xff))
	return out


## Shader source with the palette baked in as a constant array.
static func shader_code() -> String:
	var items: PackedStringArray = []
	for c: Color in colors():
		items.append("vec3(%.4f, %.4f, %.4f)" % [c.r, c.g, c.b])
	return SHADER_HEAD + "const vec3 PAL[16] = vec3[16](%s);\n" % ", ".join(items) + SHADER_BODY


static func make_shader() -> Shader:
	var sh := Shader.new()
	sh.code = shader_code()
	return sh


## Relative luminance of a colour (Rec. 709 weights on the sRGB values, good enough for a palette check).
static func luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
