Shader "CubedParadox/Flat Lit Toon Lite Transparent"
{
	Properties
	{
		_MainTex("MainTex", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_ColorMask("ColorMask", 2D) = "black" {}
		_Shadow("Shadow", Range(0, 1)) = 0.4
		_EmissionMap("Emission Map", 2D) = "white" {}
		[HDR]_EmissionColor("Emission Color", Color) = (0,0,0,1)
		_BumpMap("BumpMap", 2D) = "bump" {}
		_Cutoff("Alpha Cutoff", Range(0,1)) = 0.5
        [HideInInspector] _Cull ("__cull", Float) = 2.0
	}

	SubShader
	{
		Tags { "Queue"="Transparent" "RenderType" = "Transparent" "IgnoreProjector"="True" }
		Cull [_Cull]
		Pass
		{

			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
            Blend One OneMinusSrcAlpha
            ZWrite Off

			CGPROGRAM
			#define UNITY_PASS_FORWARDBASE
			#pragma multi_compile _ VERTEXLIGHT_ON
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON

            #define _ALPHAPREMULTIPLY_ON 1

			#define SCSS_NO_RAMP_TEXTURE 1

			#include "UnityCG.cginc"
			#include "AutoLight.cginc" 
			#include "Lighting.cginc"
			
			#include "..\CGIncludes\SCSS_Utils.cginc"
			#include "..\CGIncludes\SCSS_SimpleInput.cginc"
			#include "..\CGIncludes\SCSS_UnityGI.cginc"
			#include "..\CGIncludes\SCSS_SimpleCore.cginc"

			#pragma vertex vert_nogeom
			#pragma fragment frag_simple

			#include "..\CGIncludes\SCSS_Forward.cginc"

			#pragma only_renderers d3d11 glcore gles
			#pragma target 4.0

			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			ENDCG
		}

		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode" = "ForwardAdd" }

			Blend One One
            ZWrite Off
            Cull [_Cull]
            
			CGPROGRAM
            #define _ALPHABLEND_ON 1
			#define UNITY_PASS_FORWARDADD
			#pragma multi_compile _ VERTEXLIGHT_ON
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON

			#define SCSS_NO_RAMP_TEXTURE 1

			#include "UnityCG.cginc"
			#include "AutoLight.cginc" 
			#include "Lighting.cginc"
			
			#include "..\CGIncludes\SCSS_Utils.cginc"
			#include "..\CGIncludes\SCSS_SimpleInput.cginc"
			#include "..\CGIncludes\SCSS_UnityGI.cginc"
			#include "..\CGIncludes\SCSS_SimpleCore.cginc"

			#pragma vertex vert_nogeom
			#pragma fragment frag_simple

			#include "..\CGIncludes\SCSS_Forward.cginc"

			#pragma only_renderers d3d11 glcore gles
			#pragma target 4.0

			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			ENDCG
		}

		Pass
		{
			Name "SHADOW_CASTER"
			Tags{ "LightMode" = "ShadowCaster" }

			ZWrite On ZTest LEqual
            Cull [_Cull]

			CGPROGRAM
            #define _ALPHAPREMULTIPLY_ON 1
			#include "..\CGIncludes\SCSS_Shadows.cginc"
			#pragma multi_compile_shadowcaster
			#pragma fragmentoption ARB_precision_hint_fastest

			#pragma only_renderers d3d11 glcore gles
			#pragma target 4.0

			#pragma vertex vertShadowCaster
			#pragma fragment fragShadowCaster
			ENDCG
		}
	}
	FallBack "Diffuse"
    CustomEditor "CubedsUnityShaders.FlatLitToonLiteCutoutInspector"
}
