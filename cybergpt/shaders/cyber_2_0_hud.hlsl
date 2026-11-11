// cyber_2_0_hud.hlsl
// Subtle Cyber 2.0 HUD layer for Windows Terminal 1.24+.
// The generated effects stay behind terminal content to keep glyphs sharp.

Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings
{
    float Time;
    float Scale;
    float2 Resolution;
    float4 Background;
};

float thinLine(float coordinate, float width)
{
    float distanceFromLine = min(frac(coordinate), 1.0 - frac(coordinate));
    return 1.0 - smoothstep(0.0, width, distanceFromLine);
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float4 terminal = shaderTexture.Sample(samplerState, tex);
    float3 hudOverlay = float3(0.0, 0.0, 0.0);

    // Restrained cyan frame and inner rail, strongest at the outer edges.
    float edgeDistance = min(min(tex.x, 1.0 - tex.x), min(tex.y, 1.0 - tex.y));
    float outerFrame = 1.0 - smoothstep(0.002, 0.010, edgeDistance);
    float innerRail = 1.0 - smoothstep(0.0, 0.003, abs(edgeDistance - 0.026));
    hudOverlay += float3(0.00, 0.55, 0.78) * (outerFrame * 0.15 + innerRail * 0.050);

    // Very faint telemetry grid; it remains a background texture, not an overlay.
    float gridX = thinLine(tex.x * 18.0, 0.035);
    float gridY = thinLine(tex.y * 11.0, 0.035);
    float grid = saturate(gridX + gridY) * 0.018;
    hudOverlay += float3(0.00, 0.34, 0.48) * grid;

    // A soft animated scan and two small HUD pulses near the side panels.
    float scanPosition = frac(Time * 0.035);
    float scan = exp(-abs(tex.y - scanPosition) * 220.0);
    hudOverlay += float3(0.00, 0.42, 0.62) * scan * 0.040;

    float pulse = 0.5 + 0.5 * sin(Time * 0.82);
    float sideBand = 1.0 - smoothstep(0.055, 0.13, min(tex.x, 1.0 - tex.x));
    float ticks = thinLine(tex.y * 22.0 + Time * 0.018, 0.075) * sideBand;
    hudOverlay += float3(0.62, 0.02, 0.48) * ticks * (0.014 + pulse * 0.016);

    float2 centered = tex - 0.5;
    float vignette = saturate(1.0 - dot(centered, centered) * 1.12);
    float3 processedBackground = terminal.rgb * (0.90 + 0.10 * vignette);
    processedBackground += hudOverlay;

    // The sampled texture already contains the configured Roma background.
    // Apply the HUD only behind terminal content, then preserve the original
    // alpha so the profile backgroundImageOpacity continues to work.
    float contentCoverage = saturate(terminal.a);
    float3 finalColor = lerp(processedBackground, terminal.rgb, contentCoverage);
    return float4(saturate(finalColor), terminal.a);
}
