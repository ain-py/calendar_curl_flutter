#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform vec2 u_pointer;     // Current drag position in pixels
uniform vec2 u_origin;      // The corner being dragged (e.g., vec2(0, 0) for Top-Left)
uniform float u_radius;     // Radius of the curl cylinder (e.g., 40.0)
uniform float u_draw_background; // New: 1.0 to draw background, 0.0 to hide
uniform sampler2D u_front_texture; // The page being turned (e.g., the "1" calendar)
uniform sampler2D u_back_texture;  // The page underneath (e.g., the blank calendar)

out vec4 fragColor;

const float PI = 3.14159265359;

// Helper to get front texture with bounds check based on alpha
vec4 getFront(vec2 p) {
    if (p.x >= 0.0 && p.x <= u_resolution.x && p.y >= 0.0 && p.y <= u_resolution.y) {
        return texture(u_front_texture, p / u_resolution);
    }
    return vec4(0.0);
}

// Standard Alpha Compositing (Source Over)
void blend(inout vec4 dst, vec4 src) {
    if (src.a > 0.0) {
        float outA = src.a + dst.a * (1.0 - src.a);
        if (outA > 0.0) {
            dst.rgb = (src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / outA;
        }
        dst.a = outA;
    }
}

void main() {
    vec2 xy = FlutterFragCoord().xy;
    vec2 uv = xy / u_resolution;
    
    // Start with the background page
    vec4 color = texture(u_back_texture, uv) * u_draw_background;
    
    vec2 pullVec = u_pointer - u_origin;
    float pullDist = length(pullVec);
    
    // If no drag is occurring, render the unpeeled front page completely
    if (pullDist <= 1.0) {
        vec4 front = getFront(xy);
        blend(color, front);
        fragColor = color;
        return;
    }
    
    vec2 N = pullVec / pullDist; // Fold direction normal
    vec2 M = u_origin + pullVec * 0.5; // Fold line position
    
    // Distance from the current pixel to the fold line
    float d = dot(xy - M, N);
    float R = u_radius;
    
    // Evaluate the four overlapping layers of the curled paper.
    // We compose bottom to top so colors blend correctly.

    // 1. Bottom Layer: Flat Unpeeled Page (d > 0)
    if (d > 0.0) {
        vec4 frontTex = getFront(xy);
        if (frontTex.a > 0.0) {
            float light = 1.0 - 0.1 * exp(-d / R); // Reduced from 0.3 to 0.15
            blend(color, vec4(frontTex.rgb * light, frontTex.a));
        }
    }
    
    // Check if the Top Layer is drawing here to prevent drawing Middle shadows over it
    bool hasTopLayer = false;
    vec4 topTex;
    vec3 topRGB;
    float topLight;
    if (d > 0.0) {
        vec2 origXY = xy - N * (2.0 * d + PI * R);
        topTex = getFront(origXY);
        if (topTex.a > 0.0) {
            hasTopLayer = true;
            topLight = 0.9 + 0.1 * (1.0 - exp(-d / R));
            topRGB = vec3(0.9) * topLight;
        }
    }

    // 2 & 3. Middle Layers: The Curl Cylinder (-R <= d <= 0)
    // We only draw the cylinder shadow if this pixel IS NOT simultaneously covered 
    // by the opaque Top Layer (the folded-back part of the page)
    if (d >= -R && d <= 0.0 && !hasTopLayer) {
        // Middle Layer 1: The Curled Front Page
        float theta1 = asin(-d / R);
        float s1 = R * theta1;
        vec2 origXY1 = xy - N * (d + s1);
        vec4 frontTex1 = getFront(origXY1);
        if (frontTex1.a > 0.0) {
            float light = 1.0 - 0.1 * exp(d / R); // Reduced from 0.3 to 0.15
            blend(color, vec4(frontTex1.rgb * light, frontTex1.a));
        }

        // Middle Layer 2: The Curled Back Page
        float theta2 = PI - asin(-d / R);
        float s2 = R * theta2;
        vec2 origXY2 = xy - N * (d + s2);
        vec4 frontTex2 = getFront(origXY2);
        if (frontTex2.a > 0.0) {
            float light = 0.9 + 0.06 * sin(theta2); // Reduced from (0.8 + 0.2)
            vec3 backRGB = vec3(0.9) * light;      // Solid gray back of the page
            blend(color, vec4(backRGB, frontTex2.a));
        }
    }
    
    // 4. Top Layer: Flat Folded-Over Back Page (d > 0)
    // Draw this last so it overlays the bottom layer.
    if (hasTopLayer) {
        vec4 topLayer = vec4(topRGB, topTex.a);
        // Fully replace the underlying shadow/pixels based on alpha
        color.rgb = mix(color.rgb, topLayer.rgb, topLayer.a);
        color.a = topLayer.a + color.a * (1.0 - topLayer.a);
    }
    
    fragColor = color;
}