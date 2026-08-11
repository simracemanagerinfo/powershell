// cyber_glass_hud.hlsl
// Smoked cyberpunk HUD for Windows Terminal 1.24+.
Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings
{
    float Time;
    float Scale;
    float2 Resolution;
    float4 Background;
};

float gridLine(float coordinate, float softness)
{
    float distanceFromLine = min(frac(coordinate), 1.0 - frac(coordinate));
    return 1.0 - smoothstep(0.0, softness, distanceFromLine);
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float4 terminal = shaderTexture.Sample(samplerState, tex);
    float3 hud = lerp(float3(0.006, 0.018, 0.042), Background.rgb, 0.18);

    const float horizon = 0.43;
    float lower = saturate((tex.y - horizon) / (1.0 - horizon));
    float perspectiveWidth = lerp(0.18, 1.0, lower);
    float perspectiveX = (tex.x - 0.5) / max(perspectiveWidth, 0.02);

    float verticalGrid = gridLine(perspectiveX * 7.5, 0.055);
    float horizontalGrid = gridLine(pow(max(lower, 0.001), 0.58) * 13.0 - Time * 0.08, 0.065);
    float gridFade = smoothstep(0.05, 0.72, lower) * (0.48 + 0.52 * lower);
    float grid = saturate(verticalGrid + horizontalGrid) * gridFade;
    hud += float3(0.00, 0.34, 0.52) * grid * 0.22;

    float magentaBreath = 0.5 + 0.5 * sin(Time * 0.72);
    float horizonPulse = exp(-abs(tex.y - (horizon + 0.018)) * 105.0);
    hud += float3(0.48, 0.018, 0.39) * horizonPulse * (0.07 + 0.08 * magentaBreath);

    float scanPosition = frac(Time * 0.055);
    float scanline = exp(-abs(tex.y - scanPosition) * 260.0);
    hud += float3(0.00, 0.48, 0.68) * scanline * 0.16;

    float edgeBand = 1.0 - smoothstep(0.025, 0.075, min(tex.x, 1.0 - tex.x));
    float telemetryTicks = gridLine(tex.y * 24.0 + Time * 0.025, 0.10) * edgeBand;
    hud += float3(0.05, 0.52, 0.28) * telemetryTicks * 0.055;

    float2 centered = tex - 0.5;
    float vignette = saturate(1.0 - dot(centered, centered) * 1.22);
    hud *= 0.76 + 0.24 * vignette;

    float contentCoverage = saturate(terminal.a);
    float3 finalColor = lerp(hud, terminal.rgb, contentCoverage);
    float outputAlpha = lerp(0.34, 1.0, contentCoverage);
    return float4(saturate(finalColor), outputAlpha);
}
