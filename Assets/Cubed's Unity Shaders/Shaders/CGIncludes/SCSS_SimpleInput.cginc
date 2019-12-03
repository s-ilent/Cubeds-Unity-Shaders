#ifndef SCSS_S_INPUT_INCLUDED
#define SCSS_S_INPUT_INCLUDED

//---------------------------------------

// Keyword squeezing. 
#if (_DETAIL_MULX2 || _DETAIL_MUL || _DETAIL_ADD || _DETAIL_LERP)
    #define _DETAIL 1
#endif

//---------------------------------------

UNITY_DECLARE_TEX2D(_MainTex); uniform half4 _MainTex_ST; uniform half4 _MainTex_TexelSize;
UNITY_DECLARE_TEX2D_NOSAMPLER(_ColorMask); uniform half4 _ColorMask_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_BumpMap); uniform half4 _BumpMap_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_EmissionMap); uniform half4 _EmissionMap_ST;

// Some parameters need initialisation.

uniform float4 _Color;
uniform float _Cutoff;
uniform float _AlphaSharp = 1;
uniform float _UVSec = 0;

uniform float _UseFresnel = 0;
uniform float _FresnelWidth = 0;
uniform float _FresnelStrength = 0;
uniform float4 _FresnelTint = 0;

//uniform float _LightRampType;
uniform float _LightRampType = 2;

uniform float4 _EmissionColor;

uniform float _Shadow;

uniform float _outline_width;
uniform float4 _outline_color;
uniform float _OutlineMode;

uniform float _LightingCalculationType = 0;

uniform float4 _LightSkew = float4(1, 1, 1, 1);
uniform float _PixelSampleMode = 0;
uniform float _VertexColorType = 0;

//-------------------------------------------------------------------------------------
// Input functions

struct v2g
{
	UNITY_POSITION(vertex);
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	fixed4 color : COLOR0_centroid;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float4 posWorld : TEXCOORD2;
	float3 normalDir : TEXCOORD3;
	float3 tangentDir : TEXCOORD4;
	float3 bitangentDir : TEXCOORD5;
	float4 pos : CLIP_POS;
	half4 vertexLight : TEXCOORD6;
	half2 extraData : TEXCOORD7;
	UNITY_SHADOW_COORDS(8)
	UNITY_FOG_COORDS(9)

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct VertexOutput
{
	UNITY_POSITION(pos);
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float4 posWorld : TEXCOORD2;
	float3 normalDir : TEXCOORD3;
	float3 tangentDir : TEXCOORD4;
	float3 bitangentDir : TEXCOORD5;
	half4 vertexLight : TEXCOORD6;
	half2 extraData : TEXCOORD7;
	bool is_outline : IS_OUTLINE;
	UNITY_SHADOW_COORDS(8)
	UNITY_FOG_COORDS(9)

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct SCSS_Input 
{
	half3 albedo, specColor;
	float3 normal;
	float oneMinusReflectivity, smoothness;
	half alpha;
	half3 tonemap;
	half occlusion;
	half softness;
};

struct SCSS_LightParam
{
	half3 halfDir, reflDir;
	half2 rlPow4;
	half NdotL, NdotV, LdotH, NdotH;
};

float4 TexCoords(VertexOutput v)
{
    float4 texcoord;
	texcoord.xy = TRANSFORM_TEX(v.uv0, _MainTex);// Always source from uv0
	texcoord.xy = _PixelSampleMode? 
		sharpSample(_MainTex_TexelSize.zw * _MainTex_ST.xy, texcoord.xy) : texcoord.xy;
#if _DETAIL 
	texcoord.zw = TRANSFORM_TEX(((_UVSec == 0) ? v.uv0 : v.uv1), _DetailAlbedoMap);
	texcoord.zw = _PixelSampleMode? 
		sharpSample(_DetailAlbedoMap_TexelSize.zw * _DetailAlbedoMap_ST.xy, texcoord.zw) : texcoord.zw;
#else
	texcoord.zw = texcoord.xy;
#endif
    return texcoord;
}

half ColorMask(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER (_ColorMask, _MainTex, uv).r;
}

half3 Albedo(float4 texcoords)
{
    half3 albedo = UNITY_SAMPLE_TEX2D (_MainTex, texcoords.xy).rgb * LerpWhiteTo(_Color.rgb, 1-ColorMask(texcoords.xy));
#if _DETAIL
    half mask = DetailMask(texcoords.xy);
    half4 detailAlbedo = UNITY_SAMPLE_TEX2D_SAMPLER (_DetailAlbedoMap, _DetailAlbedoMap, texcoords.zw);
    mask *= detailAlbedo.a;
    mask *= _DetailAlbedoMapScale;
    #if _DETAIL_MULX2
        albedo *= LerpWhiteTo (detailAlbedo.rgb * unity_ColorSpaceDouble.rgb, mask);
    #elif _DETAIL_MUL
        albedo *= LerpWhiteTo (detailAlbedo.rgb, mask);
    #elif _DETAIL_ADD
        albedo += detailAlbedo.rgb * mask;
    #elif _DETAIL_LERP
        albedo = lerp (albedo, detailAlbedo.rgb, mask);
    #endif
#endif
    return albedo;
}

half Alpha(float2 uv)
{
#if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
    return _Color.a;
#else
    return UNITY_SAMPLE_TEX2D(_MainTex, uv).a * _Color.a;
#endif
}

half3 Emission(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap, _MainTex, uv).rgb;
}

half4 EmissionDetail(float2 uv)
{
#if _DETAIL 
	uv += _EmissionDetailParams.xy * _Time.y;
	half4 ed = UNITY_SAMPLE_TEX2D_SAMPLER(_DetailEmissionMap, _DetailAlbedoMap, uv);
	ed.rgb = _EmissionDetailParams.z? (sin(ed.rgb * _EmissionDetailParams.w + _Time.y * _EmissionDetailParams.z))+1 : ed.rgb;
	return ed;
#else
	return 1;
#endif
}

half3 NormalInTangentSpace(float4 texcoords, half mask)
{
	float3 normalTangent = UnpackScaleNormal(UNITY_SAMPLE_TEX2D_SAMPLER(_BumpMap, _MainTex, TRANSFORM_TEX(texcoords.xy, _MainTex)), 1.0);
#if _DETAIL 
    half3 detailNormalTangent = UnpackScaleNormal(UNITY_SAMPLE_TEX2D_SAMPLER (_DetailNormalMap, _MainTex, texcoords.zw), _DetailNormalMapScale);
    #if _DETAIL_LERP
        normalTangent = lerp(
            normalTangent,
            detailNormalTangent,
            mask);
    #else
        normalTangent = lerp(
            normalTangent,
            BlendNormalsPD(normalTangent, detailNormalTangent),
            mask);
    #endif
#endif

    return normalTangent;
}

#endif // SCSS_INPUT_INCLUDED