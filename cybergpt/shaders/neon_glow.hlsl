// neon_glow.hlsl
// Subtle neon bloom/scanline effect. Kept intentionally light for daily use.
Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings
{
    float Time;
    float Scale;
    float2 Resolution;
    float4 Background;
};

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float2 px = float2(1.0 / Resolution.x, 1.0 / Resolution.y);
    float4 c  = shaderTexture.Sample(samplerState, tex);
    float4 l  = shaderTexture.Sample(samplerState, tex - float2(px.x * 1.5, 0.0));
    float4 r  = shaderTexture.Sample(samplerState, tex + float2(px.x * 1.5, 0.0));
    float4 u  = shaderTexture.Sample(samplerState, tex - float2(0.0, px.y * 1.5));
    float4 d  = shaderTexture.Sample(samplerState, tex + float2(0.0, px.y * 1.5));

    float3 bloom = (l.rgb + r.rgb + u.rgb + d.rgb) * 0.10;
    float scan = 0.985 + 0.015 * sin(tex.y * Resolution.y * 3.14159265);

    float3 finalColor = c.rgb * scan + bloom * 0.22;
    return float4(saturate(finalColor), c.a);
}
