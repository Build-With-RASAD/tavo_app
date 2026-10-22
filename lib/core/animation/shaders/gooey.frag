// lib/core/animation/shaders/gooey.frag
//
// The gooey effect: a signed-distance blend of three moving metaballs.
//
// The uniform names are addressed by name from
// lib/core/animation/shaders/shader_painters.dart, so the declaration order
// below is free to change as long as the names stay the same.
#include <flutter/runtime_effect.glsl>

uniform float iTime;
uniform vec2 uSize;
uniform float uProgress;

out vec4 fragColor;

// The signed distance from `point` to a circle.
float blobDistance(vec2 point, vec2 center, float radius) {
    return length(point - center) - radius;
}

// The polynomial smooth minimum of two signed distances.
float smoothUnion(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec2 p = uv - vec2(0.5, 0.5);
    p.x *= uSize.x / uSize.y;

    float t = iTime * 0.6;

    float d1 = blobDistance(p, vec2(sin(t) * 0.22, cos(t * 0.8) * 0.12), 0.17);
    float d2 = blobDistance(p, vec2(cos(t * 0.6) * 0.18, sin(t * 1.1) * 0.16), 0.15);
    float d3 = blobDistance(p, vec2(sin(t * 0.4 + 1.0) * 0.10, cos(t * 0.9 + 2.0) * 0.20), 0.13);

    float d = smoothUnion(smoothUnion(d1, d2, 0.12), d3, 0.12);

    float edge = 1.0 - smoothstep(-0.02, 0.02, d);
    float glow = smoothstep(0.18, 0.0, abs(d));

    vec3 base = vec3(0.106, 0.212, 0.365);
    vec3 tint = vec3(0.239, 0.353, 0.502);
    vec3 color = mix(base, tint, uv.y) + glow * vec3(0.25, 0.30, 0.40);

    float alpha = edge * uProgress;
    fragColor = vec4(color * alpha, alpha);
}
