#if OPENGL
    #define SV_POSITION POSITION
    #define VS_SHADERMODEL vs_3_0
    #define PS_SHADERMODEL ps_3_0
#else
    #define VS_SHADERMODEL vs_4_0_level_9_1
    #define PS_SHADERMODEL ps_4_0_level_9_1
#endif

// Parameter used to set the minimum and maximum values for the Scale of the Mask Texture.
float2 RangeScale;

// Parameter used to set the minimum and maximum values for the Rotation of the Mask Texture.
// NOTE: This shader assumes that the range is in degrees and not radians, which I think is
// more intuitive when setting the parameters.
float2 RangeAngle; // in degrees

// Parameter used to advance the scene transition effect using the rangeScale and rangeAngle values.
float Progress;

Texture2D SpriteTexture : register(t0);
Texture2D MaskTexture : register(t1);

sampler2D SpriteTextureSampler : register(s0) = sampler_state
{
    Filter = Point;
    Texture = <SpriteTexture>;
};

sampler2D MaskTextureSampler : register(s1) = sampler_state
{
    Filter = Point;
    Texture = <MaskTexture>;
    AddressU = Clamp;
    AddressV = Clamp;
};  

struct VertexShaderOutput
{
    float4 Position : SV_POSITION;
    float4 Color : COLOR0;
    float2 TextureCoordinates : TEXCOORD0;
};

// Rotates a vector by a given angle.
float2 rotate2D(float2 v, float angle)
{
    float c = cos(angle);
    float s = sin(angle);

    float2x2 rMatrix = {
        c, -s,
        s, c
    };

    return mul(rMatrix, v);
}

float4 MainPS(VertexShaderOutput input) : COLOR
{
    // Linearly interpolate between the minimum and maximum values for the scaling and rotation of the effect
    // using the Progress parameter.
    float scale = lerp(RangeScale.x, RangeScale.y,  1 - Progress);
    float angle_degrees = lerp(RangeAngle.x, RangeAngle.y,  1 - Progress);
    float angle = radians(angle_degrees);    

    // Vector used to correct the mask texture (which is in a 1:1 ratio) to the 16:9 ratio of the screen.
    float2 aspect_ratio = float2(16.0f/9.0f, 1);

    // The mask texture is scaled around the center of the image.
    // Change this value if you want the image to scale using another reference point.
    float2 center = float2(.5f, .5f);   

    // Coordinates from the main texture.
    float2 uv = input.TextureCoordinates;

    // First, scale the mask texture using the aspect ratio to correct the image.
    // Without this step, the image will get stretched in the x direction.
    float2 uv_corrected = (uv - center) * aspect_ratio + center;

    // Then, scale the mask texture by the current scale amount.
    float2 uv_scaled = (uv_corrected - center) * scale + center;

    // Finally, rotate the mask texture by the current angle amount.
    float2 uv_rotated = rotate2D(uv_scaled - center, angle) + center; 

    // Sample the scaled mask texture.
    float4 color = tex2D(MaskTextureSampler, uv_rotated);

    // The mask texture uses white pixels to know which pixels should be made transparent.
    return color * (1 - color.r);
}

technique SpriteDrawing
{
    pass PO
    {
        PixelShader = compile PS_SHADERMODEL MainPS();
    }
};

