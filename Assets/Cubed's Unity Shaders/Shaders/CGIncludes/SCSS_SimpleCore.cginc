#ifndef SCSS_CORE_INCLUDED
#define SCSS_CORE_INCLUDED

#define SCSS_UNIMPORTANT_LIGHTS_FRAGMENT 1

struct SCSS_Light
{
    half3 color;
    half3 dir;
    half  intensity; 
};

SCSS_Light MainLight()
{
    SCSS_Light l;

    l.color = _LightColor0.rgb;
    l.intensity = _LightColor0.w;
    l.dir = Unity_SafeNormalize(_WorldSpaceLightPos0.xyz); 
    return l;
}

// Shade4PointLights from UnityCG.cginc but only returns their attenuation.
float4 Shade4PointLightsAtten (
    float4 lightPosX, float4 lightPosY, float4 lightPosZ,
    float4 lightAttenSq,
    float3 pos, float3 normal)
{
    // to light vectors
    float4 toLightX = lightPosX - pos.x;
    float4 toLightY = lightPosY - pos.y;
    float4 toLightZ = lightPosZ - pos.z;
    // squared lengths
    float4 lengthSq = 0;
    lengthSq += toLightX * toLightX;
    lengthSq += toLightY * toLightY;
    lengthSq += toLightZ * toLightZ;
    // don't produce NaNs if some vertex position overlaps with the light
    lengthSq = max(lengthSq, 0.000001);

    // NdotL
    float4 ndotl = 0;
    ndotl += toLightX * normal.x;
    ndotl += toLightY * normal.y;
    ndotl += toLightZ * normal.z;
    // correct NdotL
    float4 corr = 0;//rsqrt(lengthSq);
    corr.x = fastRcpSqrtNR0(lengthSq.x);
    corr.y = fastRcpSqrtNR0(lengthSq.y);
    corr.z = fastRcpSqrtNR0(lengthSq.z);
    corr.w = fastRcpSqrtNR0(lengthSq.x);

    ndotl = corr * (ndotl * 0.5 + 0.5); // Match with Forward for light ramp sampling
    ndotl = max (float4(0,0,0,0), ndotl);
    // attenuation
    float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
    float4 diff = ndotl * atten;
    #if defined(SCSS_UNIMPORTANT_LIGHTS_FRAGMENT)
    return atten;
    #else
    return diff;
    #endif
}

// Based on Standard Shader's forwardbase vertex lighting calculations in VertexGIForward
// This revision does not pass the light values themselves, but only their attenuation.
inline half4 VertexLightContribution(float3 posWorld, half3 normalWorld)
{
	half4 vertexLight = 0;

	// Static lightmaps
	#ifdef LIGHTMAP_ON
		return 0;
	#elif UNITY_SHOULD_SAMPLE_SH
		#ifdef VERTEXLIGHT_ON
			// Approximated illumination from non-important point lights
			vertexLight = Shade4PointLightsAtten(
				unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
				unity_4LightAtten0, posWorld, normalWorld);
		#endif
	#endif

	return vertexLight;
}

float applyShadowLift(float baseLight, float occlusion)
{
	baseLight *= (1 - _Shadow) * occlusion + _Shadow;
	//baseLight = _ShadowLift + baseLight * (1-_ShadowLift);
	return baseLight;
}

float getRemappedLight(half perceptualRoughness, half attenuation, SCSS_LightParam d)
{
	float remappedLight = d.NdotL * attenuation
		* DisneyDiffuse(d.NdotV, d.NdotL, d.LdotH, perceptualRoughness);
	return remappedLight;
}

void getDirectIndirectLighting(float3 normal, inout float3 directLighting, inout float3 indirectLighting)
{
	switch (_LightingCalculationType)
	{
	case 0: // Arktoon
		directLighting   = GetSHLength();
		indirectLighting = BetterSH9(half4(0.0, 0.0, 0.0, 1.0)); 
	break;
	case 1: // Standard
		directLighting = 
		indirectLighting = BetterSH9(half4(normal, 1.0))
						 + SHEvalLinearL2(half4(normal, 1.0));
	break;
	case 2: // Cubed
		directLighting   = BetterSH9(half4(0.0,  1.0, 0.0, 1.0));
		indirectLighting = BetterSH9(half4(0.0, -1.0, 0.0, 1.0)); 
	break;
	case 3: // True Directional
		float4 ambientDir = float4(Unity_SafeNormalize(unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz), 1.0);
		directLighting   = BetterSH9(ambientDir);
		indirectLighting = BetterSH9(-ambientDir); 
	break;
	}

}

half3 calcDiffuseBase(float3 tonemap, float occlusion, half3 normal, half perceptualRoughness, half attenuation, 
	half smoothness, half softness, SCSS_LightParam d, SCSS_Light l)
{
	float remappedLight = getRemappedLight(perceptualRoughness, attenuation, d);

	float3 lightContribution = sampleRampWithOptions(remappedLight, softness);

	float3 directLighting = 0.0;
	float3 indirectLighting = 0.0;

	getDirectIndirectLighting(normal, /*out*/ directLighting, /*out*/ indirectLighting);

	indirectLighting = lerp(indirectLighting, directLighting, tonemap);

	lightContribution = lerp(tonemap, 1.0, lightContribution);
	lightContribution *= l.color;
	
	float3 ambientLightDirection = Unity_SafeNormalize((unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz));
	float ambientLight = dot(normal, ambientLightDirection);

	lightContribution += lerp(indirectLighting, directLighting, sampleRampWithOptions(ambientLight, softness));

	return lightContribution;	
}

half3 calcDiffuseAdd(float3 tonemap, float occlusion, half perceptualRoughness, 
	half smoothness, half softness, SCSS_LightParam d, SCSS_Light l)
{
	float remappedLight = getRemappedLight(perceptualRoughness, 1.0, d);

	float3 lightContribution = sampleRampWithOptions(remappedLight, softness);

	float3 directLighting = l.color;
	float3 indirectLighting = l.color * tonemap;
	
	lightContribution = lerp(indirectLighting, directLighting, lightContribution);
	return lightContribution;
}

half3 calcVertexLight(float4 vertexAttenuation, float occlusion, float3 tonemap, half softness)
{
	float3 vertexContribution = 0;
	#if defined(UNITY_PASS_FORWARDBASE)
		// Vertex lighting based on Shade4PointLights
		float4 vertexAttenuationFalloff = saturate(vertexAttenuation * 10);

	    vertexContribution += unity_LightColor[0] * (sampleRampWithOptions(vertexAttenuation.x, softness)+tonemap) * vertexAttenuationFalloff.x;
	    vertexContribution += unity_LightColor[1] * (sampleRampWithOptions(vertexAttenuation.y, softness)+tonemap) * vertexAttenuationFalloff.y;
	    vertexContribution += unity_LightColor[2] * (sampleRampWithOptions(vertexAttenuation.z, softness)+tonemap) * vertexAttenuationFalloff.z;
	    vertexContribution += unity_LightColor[3] * (sampleRampWithOptions(vertexAttenuation.w, softness)+tonemap) * vertexAttenuationFalloff.w;
	#endif
	return vertexContribution;
}

float3 SCSS_ApplyLightingSimple(SCSS_Input c, SCSS_LightParam d, VertexOutput i, float3 viewDir, SCSS_Light l,
	float2 texcoords)
{
	UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);

	float perceptualRoughness = 0;

	float3 finalColor; 

	#if defined(UNITY_PASS_FORWARDBASE)
	finalColor = calcDiffuseBase(c.tonemap, c.occlusion, c.normal, 
		perceptualRoughness, attenuation, c.smoothness, c.softness, d, l);
	#endif

	#if defined(UNITY_PASS_FORWARDADD)
	finalColor = calcDiffuseAdd(c.tonemap, c.occlusion, 
		perceptualRoughness, c.smoothness, c.softness, d, l);
	#endif

	// Proper cheap vertex lights. 
	#if defined(VERTEXLIGHT_ON) && !defined(SCSS_UNIMPORTANT_LIGHTS_FRAGMENT)
	finalColor += calcVertexLight(i.vertexLight, c.occlusion, c.tonemap, c.softness);
	#endif

	finalColor *= c.albedo;
	return finalColor;

    // Apply full lighting to unimportant lights. This is cheaper than you might expect.
	#if defined(UNITY_PASS_FORWARDBASE) && defined(VERTEXLIGHT_ON) && defined(SCSS_UNIMPORTANT_LIGHTS_FRAGMENT)
    for (int num = 0; num < 4; num++) {
    	l.color = unity_LightColor[num].rgb;
    	l.dir = normalize(float3(unity_4LightPosX0[num], unity_4LightPosY0[num], unity_4LightPosZ0[num]) - i.posWorld.xyz);

    	d.NdotL = saturate(dot(l.dir, c.normal)); // Calculate NdotL
		d.halfDir = Unity_SafeNormalize (l.dir + viewDir);
		d.LdotH = saturate(dot(l.dir, d.halfDir));
		d.NdotH = saturate(dot(c.normal, d.halfDir));

    	finalColor += calcDiffuseAdd(c.tonemap, c.occlusion, perceptualRoughness, c.smoothness, c.softness, d, l) * c.albedo * i.vertexLight[num];
    };
	#endif

	#if defined(UNITY_PASS_FORWARDADD)
		finalColor *= attenuation;
	#endif
	return finalColor;
}

#endif // SCSS_CORE_INCLUDED