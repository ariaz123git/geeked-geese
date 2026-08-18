shader_type canvas_item;
render_mode unshaded;

// Per-substance screen treatment. One shader, one branch per substance family.
// This file is where most of the "wow" budget should go — it's shader work,
// so one person can do all of it, and it costs no art assets.
//
// mode: 0 none | 1 wobble (ethanol) | 2 jitter (caffeine) | 3 slowmo (nitrous)
//       4 blackout | 5 trip/kaleidoscope (toad slime) | 6 macropsia warp (fly agaric)
//       7 acid flow (LSD)

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform int mode = 0;
uniform float strength = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

vec3 sample_ca(vec2 uv, float amt) {
	// Chromatic aberration pulling outward from centre.
	vec2 dir = uv - vec2(0.5);
	float r = texture(screen_tex, uv - dir * amt).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv + dir * amt).b;
	return vec3(r, g, b);
}

vec3 hue_rot(vec3 c, float a) {
	// Rodrigues rotation about the grey axis. Cheap true hue cycling.
	const vec3 k = vec3(0.57735027);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

vec2 kaleidoscope(vec2 uv, float sectors) {
	vec2 p = uv - vec2(0.5);
	float r = length(p);
	float a = atan(p.y, p.x);
	float seg = 6.2831853 / sectors;
	a = abs(mod(a, seg) - seg * 0.5);
	return vec2(cos(a), sin(a)) * r + vec2(0.5);
}

float vignette(vec2 uv, float amount, float softness) {
	float d = distance(uv, vec2(0.5)) * 1.414;
	return 1.0 - smoothstep(1.0 - amount - softness, 1.0 - amount, d) * amount * 1.6;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float s = clamp(strength, 0.0, 2.0);
	vec3 col;

	if (mode == 1) {
		// ---- ETHANOL: slow lateral swim + doubled vision + warm shift ----
		float t = TIME * 1.15;
		uv.x += sin(uv.y * 5.0 + t) * 0.010 * s;
		uv.y += cos(uv.x * 4.0 + t * 0.8) * 0.008 * s;
		col = sample_ca(uv, 0.006 * s);
		// The double-vision ghost is the whole read. Keep it subtle or it's unplayable.
		vec2 ghost = uv + vec2(sin(t * 0.7), cos(t * 0.55)) * 0.012 * s;
		col = mix(col, texture(screen_tex, ghost).rgb, 0.30 * s);
		col *= mix(vec3(1.0), vec3(1.10, 1.02, 0.88), s * 0.6);
		col *= vignette(uv, 0.30 * s, 0.45);

	} else if (mode == 2) {
		// ---- CAFFEINE: high-frequency jitter, crushed contrast, tight vignette ----
		float t = TIME * 60.0;
		vec2 j = vec2(
			fract(sin(t) * 43758.5453) - 0.5,
			fract(sin(t * 1.7) * 22578.1459) - 0.5
		) * 0.0035 * s;
		uv += j;
		col = sample_ca(uv, 0.004 * s);
		col = (col - 0.5) * (1.0 + 0.35 * s) + 0.5;      // contrast punch
		col *= mix(vec3(1.0), vec3(1.04, 1.0, 0.94), s);
		float pulse = 0.16 + 0.10 * sin(TIME * 11.0);
		col *= vignette(uv, pulse * s, 0.35);

	} else if (mode == 3) {
		// ---- NITROUS: radial smear, blue shift, tunnel ----
		vec2 dir = (uv - vec2(0.5));
		col = vec3(0.0);
		float total = 0.0;
		for (int i = 0; i < 6; i++) {
			float f = float(i) / 5.0;
			float w = 1.0 - f;
			col += texture(screen_tex, uv - dir * f * 0.055 * s).rgb * w;
			total += w;
		}
		col /= total;
		col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))), 0.35 * s);
		col *= mix(vec3(1.0), vec3(0.78, 0.90, 1.28), s * 0.8);
		col *= vignette(uv, 0.34 * s, 0.55);
		col *= 1.0 + 0.18 * s;   // claw some exposure back — it must stay playable

	} else if (mode == 5) {
		// ---- TOAD SLIME: the full ride. Kaleidoscope fold, hue cycle,
		// breathing zoom. You cannot end this early, so it has to stay
		// navigable — the fold blends in by strength rather than snapping on.
		float t = TIME;
		vec2 p = uv - vec2(0.5);
		p *= 1.0 + sin(t * 0.8) * 0.08 * s;                 // breathing
		p = mix(p, (kaleidoscope(p + vec2(0.5), 6.0) - vec2(0.5)) * 1.6, 0.55 * clamp(s, 0.0, 1.0));
		vec2 wuv = p + vec2(0.5);
		wuv += vec2(sin(wuv.y * 8.0 + t * 1.4), cos(wuv.x * 7.0 + t * 1.1)) * 0.014 * s;
		col = sample_ca(clamp(wuv, vec2(0.001), vec2(0.999)), 0.010 * s);
		col = hue_rot(col, t * 0.9 * s + length(p) * 3.0 * s);
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(lum), col, 1.0 + 0.9 * s);            // oversaturate
		col *= vignette(uv, 0.24 * s, 0.5);
		col *= 1.0 + 0.12 * s;

	} else if (mode == 6) {
		// ---- FLY AGARIC: macropsia. The lens itself pulses between barrel and
		// pincushion so the world seems to swell and recede. The real size
		// change is the goose scaling in the controller — this only sells it.
		float t = TIME;
		vec2 p = uv - vec2(0.5);
		float r2 = dot(p, p);
		float k = sin(t * 0.62) * 0.85 * s;
		p *= 1.0 + k * r2 * 2.2;
		p *= 1.0 - k * 0.10;
		vec2 wuv = clamp(p + vec2(0.5), vec2(0.001), vec2(0.999));
		col = sample_ca(wuv, 0.005 * s * (0.5 + abs(k)));
		// Warm when swelling, cool when shrinking. Gives the pulse a direction.
		col *= mix(vec3(1.0), (k > 0.0 ? vec3(1.10, 1.01, 0.90) : vec3(0.92, 0.99, 1.12)), abs(k));
		col *= vignette(uv, 0.20 * s + abs(k) * 0.18, 0.5);

	} else if (mode == 7) {
		// ---- ACID: flowing hue rotation and drifting warp, no kaleidoscope.
		// Deliberately distinct from mode 5 (toad slime): that one folds the
		// screen into symmetry, this one keeps the world intact and makes it
		// breathe and bleed colour. Two trips should never look the same.
		float t = TIME;
		vec2 p = uv - vec2(0.5);
		// Slow domain-warped flow field.
		float w1 = sin(uv.y * 6.0 + t * 0.7) * cos(uv.x * 5.0 - t * 0.5);
		float w2 = cos(uv.x * 7.0 - t * 0.6) * sin(uv.y * 4.0 + t * 0.4);
		vec2 wuv = uv + vec2(w1, w2) * 0.022 * s;
		// Gentle breathing in and out.
		wuv = vec2(0.5) + (wuv - vec2(0.5)) * (1.0 + sin(t * 0.55) * 0.045 * s);
		wuv = clamp(wuv, vec2(0.001), vec2(0.999));
		col = sample_ca(wuv, 0.009 * s);
		// Hue rotates by luminance AND radius, so surfaces separate into bands.
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		col = hue_rot(col, (t * 0.55 + lum * 2.6 + length(p) * 1.8) * s);
		col = mix(vec3(lum), col, 1.0 + 1.15 * s);
		// Edge bloom: bright things smear outward and glow.
		vec3 blur = vec3(0.0);
		for (int i = 0; i < 4; i++) {
			float a = 1.5707963 * float(i) + t * 0.3;
			blur += texture(screen_tex, clamp(wuv + vec2(cos(a), sin(a)) * 0.006 * s, vec2(0.001), vec2(0.999))).rgb;
		}
		col += max(blur * 0.25 - vec3(0.42), vec3(0.0)) * 0.85 * s;
		col *= vignette(uv, 0.16 * s, 0.5);

	} else if (mode == 4) {
		// ---- BLACKOUT: you took a third thing. Lights out. ----
		col = texture(screen_tex, uv).rgb;
		col = mix(col, vec3(0.0), clamp(s, 0.0, 1.0));

	} else {
		col = texture(screen_tex, uv).rgb;
	}

	col *= mix(vec3(1.0), tint.rgb, 0.10 * s);
	COLOR = vec4(col, 1.0);
}
