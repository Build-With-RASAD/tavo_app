// lib/core/animation/shaders/liquid.frag
//
// The liquid effect: a refraction of a vertical gradient through an
// animated normal.
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
    vec2 p = uv - vec2(0.5, 0.5);
    p.x *= uSize.x / uSize.y;

    float t = iTime * 0.5;

    // The animated normal of the surface.
    float nx = sin(p.y * 8.0 + t * 2.0) * 0.5 + cos(p.x * 6.0 - t * 1.5) * 0.5;
    float ny = cos(p.x * 8.0 - t * 1.7) * 0.5 + sin(p.y * 6.0 + t * 1.3) * 0.5;

    // The refracted sample point of the gradient underneath.
    vec2 refracted = p + vec2(nx, ny) * 0.03;
    float depth = clamp(0.5 + refracted.y * 0.8, 0.0, 1.0);

    vec3 top = vec3(0.298, 0.549, 1.0);
    vec3 bottom = vec3(0.016, 0.118, 0.302);
    vec3 color = mix(bottom, top, depth);

    float wave = sin(length(p) * 18.0 - t * 3.0) * 0.5 + 0.5;
    float caustic = pow(wave, 3.0) * 0.35;
    color += vec3(caustic * 0.6, caustic * 0.85, caustic);

    float alpha = uProgress;
    fragColor = vec4(color * alpha, alpha);
}
