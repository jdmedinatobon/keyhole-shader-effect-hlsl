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
float2 RangeAngle;

// Parameter used to advance the scene transition effect using the rangeScale and rangeAngle values.
float Progress;

Texture2D SpriteTexture: register(t0);
Texture2D MaskTexture : register(t1);

// IMPORTANT: The SpriteTextureSampler MUST come first before the MaskTextureSampler.
// Otherwise, the main texture coming from the SpriteBatch.Draw will override the 
// mask texture being set by parameter.
// Try moving the MaskTextureSampler before the SpriteTextureSampler. It will stop working,
// since it will now set the MaskTexture to what is being drawn, which is a black screen.
// See this post for more information: https://www.reddit.com/r/monogame/comments/1ayv56z/how_do_i_pass_a_texture2d_into_a_hlsl_shader/
// NOTE: From what I read, the order of the Texture2D parameters (SpriteTexture and MaskTexture)
// should also be important, with the main texture parameter (SpriteTexture) coming first. However,
// I tried changing the order and didn't see any changes.
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
 
    // Testing using an exponential interpolation. It looks a bit strange with linear interpolation, since 
    // it grows or shrinks very quickly at first and then kind of stays similar.
    // float scale = RangeScale.y * pow(RangeScale.x / RangeScale.y, Progress);
    // float scale = RangeScale.y;
    // For some reason, testing this made the project begin to use the custom font atlas instead of the mask wait what?

    // Vector used to correct the mask texture (which is in a 1:1 ratio) to the 16:9 ratio of the screen.
    float2 aspect_ratio = float2(16.0f/9.0f, 1);

    // The mask texture is scaled around the center of the image.
    // Change this value if you want the image to scale using another reference point.
    float2 center = float2(.5f, .5f);   

    // Coordinates from the main texture. Used later so that the main texture sampler does not get optimized out.
    // IMPORTANT: Do NOT modify this part. Accidentally changing the value of uv where the y component (uv.y) can
    // be negative causes issues.
    float2 uv = input.TextureCoordinates;
    
    // Removing this if (which never happens) I think causes the SpriteTexture to be compiled out, which
    // means that the MaskTexture gets used for the rendered image? Weird.
    if (uv.y < 0)
    {
        return tex2D(SpriteTextureSampler, uv);
        // return float4(1, 0, 0, 1);
    }

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
    if (color.r == 1)
    {
        color = float4(0, 0, 0, 0);
    }

    // NOTE: If the mask texture is not black and white, it will get drawn on top. This is what is happening when,
    // for some reason, the mask texture is being replaced by my custom font atlas?! the hell?!
    // Or, maybe the SpriteTexture is the one causing issues and there is a problem with the sampler?
    return color;
}

technique SpriteDrawing
{
    pass PO
    {
        PixelShader = compile PS_SHADERMODEL MainPS();
    }
};

