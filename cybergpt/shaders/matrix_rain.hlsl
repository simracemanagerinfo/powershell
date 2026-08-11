// matrix_rain.hlsl
// Procedural Matrix-like rain behind the terminal contents.
// Windows Terminal pixel shader interface.
Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings
{
    float Time;
    float Scale;
    float2 Resolution;
    float4 Background;
};

float hash21(float2 p)
{
    p = frac(p * float2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return frac(p.x * p.y);
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float4 sample = shaderTexture.Sample(samplerState, tex);

    float columns = max(38.0, floor(Resolution.x / 13.0));
    float rows = max(28.0, floor(Resolution.y / 15.0));

    float column = floor(tex.x * columns);
    float row = floor(tex.y * rows);

    float speed = 0.055 + hash21(float2(column, 3.0)) * 0.13;
    float head = frac(Time * speed + hash21(float2(column, 11.0)));
    float behindHead = frac(tex.y - head + 1.0);

    float trail = saturate(1.0 - behindHead * 8.5);
    float changingRow = row + floor(Time * (2.0 + speed * 20.0));
    float glyph = step(0.68, hash21(float2(column, changingRow)));

    float rain = trail * glyph;
    float headGlow = pow(saturate(1.0 - behindHead * 28.0), 2.0);
    float scan = 0.965 + 0.035 * sin(tex.y * Resolution.y * 3.14159265);

    float3 bg = float3(0.0, 0.010, 0.003);
    bg += float3(0.00, 0.18, 0.035) * rain;
    bg += float3(0.16, 0.55, 0.22) * headGlow * glyph;

    float3 text = sample.rgb * scan;
    text += float3(0.00, 0.035, 0.006) * sample.a;

    return float4(lerp(bg, text, sample.a), 1.0);
}
