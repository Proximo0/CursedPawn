class_name RoomPalette
extends RefCounted
## The occult palette for the shop room and the post shader that squeezes the 640x360 render into it:
## 16 colours (cold purples, sickly greens, candle amber, bone white, blood reds) and a 4x4 Bayer ordered dither.

const SIZE: int = 16
const HEX: Array[int] = [
	0x05060b, 0x121528, 0x2a2346, 0x4a3f72, 0x7d78a8,  # cold purples, dark to light
	0x15291f, 0x2f5a3c, 0x7fa84a,  # sickly greens
	0x3a2218, 0x7a4a26, 0xd98a2b, 0xf2c15a,  # wood browns and candle ambers
	0x5c1020, 0xc8363f,  # blood reds
	0xc4c0b0, 0xf0ead8,  # bone
]

const VIEW_W: float = 640.0
const VIEW_H: float = 360.0

const SHADER_HEAD: String = """shader_type canvas_item;
uniform bool dither_on = true;
uniform float dither_strength = 0.14;
uniform vec2 res = vec2(640.0, 360.0);
uniform float vignette = 0.55;
uniform float grain = 0.035;
uniform vec4 heat0 = vec4(0.0, 0.0, 0.1, 0.0);
uniform vec4 heat1 = vec4(0.0, 0.0, 0.1, 0.0);
uniform vec4 heat2 = vec4(0.0, 0.0, 0.1, 0.0);
uniform vec4 heat3 = vec4(0.0, 0.0, 0.1, 0.0);
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
"""

const SHADER_BODY: String = """
float noise_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// heat shimmer: a wobble of the picture just above each flame (xy = flame uv, z = radius, w = strength)
vec2 heat_off(vec2 uv, vec4 h) {
	vec2 d = (uv - h.xy) / max(h.z, 0.001);
	float m = smoothstep(1.0, 0.0, length(vec2(d.x * 1.8, (d.y + 0.6) * 0.7)));
	float w = sin(uv.y * 220.0 + TIME * 6.0) + 0.5 * sin(uv.y * 410.0 - TIME * 9.0);
	return vec2(w * 0.0016 * h.w * m, 0.0);
}

void fragment() {
	vec2 suv = UV + heat_off(UV, heat0) + heat_off(UV, heat1) + heat_off(UV, heat2) + heat_off(UV, heat3);
	vec3 c = texture(TEXTURE, suv).rgb;
	ivec2 p = ivec2(floor(UV * res));
	vec2 q = UV - vec2(0.5);
	c *= clamp(1.0 - vignette * dot(q, q) * 2.4, 0.0, 1.0);
	float f = floor(TIME * 12.0);
	c += vec3((noise_hash(vec2(p) + vec2(f * 17.0, f * 31.0)) - 0.5) * grain);
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
