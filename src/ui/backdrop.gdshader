shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.06, 0.08, 0.26, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.015, 0.02, 0.08, 1.0);
uniform vec4 glow_a : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform vec4 glow_b : source_color = vec4(0.8, 0.4, 1.0, 1.0);
uniform float scroll = 0.0;
uniform vec2 aspect = vec2(1.7778, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, pow(uv.y, 0.8));
	vec2 p = vec2(uv.x * aspect.x, uv.y);

	// Big soft drifting blooms
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float h1 = hash(vec2(fi, 3.1));
		float h2 = hash(vec2(fi, 7.7));
		float h3 = hash(vec2(fi, 1.3));
		float span = aspect.x + 1.2;
		float x = mod(h1 * span - scroll * (0.00006 + 0.00004 * h2) + TIME * 0.006 * (h2 - 0.5), span) - 0.6;
		float y = 0.15 + 0.7 * h3 + 0.05 * sin(TIME * (0.2 + h2 * 0.3) + fi * 2.0);
		float rad = 0.22 + 0.26 * h2;
		float d = distance(p, vec2(x, y));
		float k = smoothstep(rad, 0.0, d);
		vec3 c = mix(glow_a.rgb, glow_b.rgb, h3);
		col += c * k * k * 0.22;
	}

	// Stars / dust motes with twinkle
	for (int layer = 0; layer < 2; layer++) {
		float fl = float(layer);
		float density = 26.0 + fl * 22.0;
		vec2 q = vec2(p.x + scroll * (0.00004 + fl * 0.00006), p.y) * density;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float r = hash(cell + fl * 17.0);
		if (r > 0.9) {
			vec2 sp = vec2(hash(cell + 3.3), hash(cell + 9.1)) * 0.6 + 0.2;
			float dd = distance(f, sp);
			float tw = 0.5 + 0.5 * sin(TIME * (1.0 + r * 3.0) + r * 40.0);
			float s = smoothstep(0.09 - fl * 0.03, 0.0, dd) * (0.35 + 0.65 * tw);
			col += mix(vec3(1.0), glow_a.rgb, 0.4) * s * (0.55 - fl * 0.15);
		}
	}

	float vig = 1.0 - 0.5 * pow(length((uv - 0.5) * vec2(1.1, 1.0)) * 1.25, 2.0);
	col *= clamp(vig, 0.0, 1.0);
	COLOR = vec4(col, 1.0);
}
