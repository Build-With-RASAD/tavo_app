// lib/core/animation/shaders/aurora.frag
//
// The aurora effect: an animated gradient mesh.
//
// The uniform names are addressed by name from
// lib/core/animation/shaders/shader_painters.dart, so the declaration order
// below is free to change as long as the names stay the same.
#include <flutter/runtime_effect.glsl>

uniform float iTime;
uniform vec2 uSize;
uniform float uProgress;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    float t = iTime * 0.35;

    // Two slow, drifting fields that bend the gradient around.
    vec2 q = vec2(sin(t * 0.7 + uv.y * 3.0), cos(t * 0.6 + uv.x * 2.5));
    vec2 r = vec2(sin(t * 0.5 + uv.y * 5.0 + 1.7), cos(t * 0.8 + uv.x * 4.0 + 0.6));

    vec3 green = vec3(0.102, 0.851, 0.549);
    vec3 violet = vec3(0.353, 0.251, 0.949);
    vec3 rose = vec3(0.949, 0.353, 0.702);

    float f1 = smoothstep(0.30, 0.90, uv.y + q.x * 0.20);
    float f2 = smoothstep(0.30, 0.90, uv.x + r.y * 0.20);
    float f3 = smoothstep(0.15, 0.85, 1.0 - length(uv - vec2(0.5, 0.5) - q * 0.10));

    vec3 color = mix(rose, violet, f1);
    color = mix(color, green, f2 * 0.7);
    color += rose * f3 * 0.22;

    float alpha = uProgress;
    fragColor = vec4(color * alpha, alpha);
}
