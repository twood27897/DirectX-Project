// Texture pixel/fragment shader
// Basic fragment shader for rendering textured geometry

// Texture and sampler registers
Texture2D texture0 : register(t0);
Texture2D texture1 : register(t1);
Texture2D texture2 : register(t2);
Texture2D texture3 : register(t3);
SamplerState sampler0 : register(s0);

// Lighting information
cbuffer LightBufferType : register(b0)
{
	float4 ambient[2];
	float4 diffuse[2];
	float4 direction[2];
	float4 lightPosition[2];
	float4 specular[2];
};

struct InputType
{
	float4 position : SV_POSITION;
	float2 tex : TEXCOORD0;
    float3 normal : NORMAL;
    float3 tangent : TANGENT;
    float3 binormal : BINORMAL;
	float3 worldPosition : TEXCOORD1;
	float3 viewVector : TEXCOORD2;
};

// Calculate lighting intensity based on direction and normal. Combine with light colour.
float4 calculateLighting(float3 lightDirection, float3 normal, float4 diffuse)
{
	float intensity = saturate(dot(normal, lightDirection));
	float4 colour = saturate(diffuse * intensity);
	return colour;
}

// Calculate spotlight lighting values
float4 calculateSpotLighting(float3 lightToPixel, float3 lightDirection, float3 normal, float4 diffuse)
{
	float spotlightFactor = dot(lightToPixel, lightDirection);
	float spotlightCutoff = cos(0.785f);

	if (spotlightFactor > spotlightCutoff)
	{
		float4 lightColour = calculateLighting(-lightDirection, normal, diffuse);
		return lightColour * (1.0f - (1.0f - spotlightFactor) * 1.0f / (1.0f - spotlightCutoff));
	}
	else
	{
		return float4(0, 0, 0, 0);
	}
}

// Attenuation calculation
float calculateAttenuation(float distance, float constantFactor, float linearFactor, float quadraticFactor)
{
	float attenuation = 1.0f / (constantFactor + (linearFactor * distance) + (quadraticFactor * pow(distance, 2)));
	return attenuation;
}

// blinn-phong specular calculation
float4 calcSpecular(float3 lightDirection, float3 normal, float3 viewVector, float3 specularColour, float specularPower)
{
	float3 halfway = normalize(lightDirection + viewVector);
	float specularIntensity = pow(max(dot(normal, halfway), 0.0), specularPower);
	return saturate(float4(specularColour, 1.0f) * specularIntensity);
}

// Calculate spotlight lighting values
float4 calculateSpecularSpotLighting(float3 lightToPixel, float3 lightDirection, float3 normal, float3 viewVector, float3 specularColour, float specularPower)
{
	float spotlightFactor = dot(lightToPixel, lightDirection);
	float spotlightCutoff = cos(0.785f);

	// Check if light is in spotlight cutoff range
	if (spotlightFactor > spotlightCutoff)
	{
		float4 lightColour = calcSpecular(-lightDirection, normal, viewVector, specularColour, specularPower);
		return lightColour * (1.0f - (1.0f - spotlightFactor) * 1.0f / (1.0f - spotlightCutoff));
	}
	else
	{
		return float4(0, 0, 0, 0);
	}
}

float greaterThanZeroCheck(float x)
{
	return x > 0 ? 1 : 0;
}

float4 main(InputType input) : SV_TARGET
{
	// Calculate world space normal from normal map
	// Sample and change to range -0.5 to 0.5
	float4 sampledNormal = normalize(texture1.Sample(sampler0, input.tex) - float4(0.5f, 0.5f, 0.5f, 0.0f));

	// Translate from tangent to world space
	float3 newNormal = input.normal + (sampledNormal.x * input.tangent + sampledNormal.y * input.binormal);

	// Normalize
	newNormal = normalize(newNormal);

	// Required lighting arrays
	float4 lightingColour[2];
	float4 specularValue[2];

	// Per light check lighting values
	for (int iterator = 0; iterator < 2; iterator++)
	{
		// Calculate attenuation
		float3 lightVector = normalize(lightPosition[iterator].xyz - input.worldPosition);
		float vertexToLightDistance = distance(lightPosition[iterator].xyz, input.worldPosition);
		float attenuationValue = calculateAttenuation(vertexToLightDistance, 0.5f, 0.125f, 0.1f);

		// Find direction from light to pixel
		float3 directionFromLight = normalize(input.worldPosition - lightPosition[iterator].xyz);

		// Calculate point light effect on geometry
		float4 pointLightColour = calculateLighting(-directionFromLight, newNormal, diffuse[iterator] * attenuationValue) * direction[iterator].w;

		// Calculate spotlight effect on geometry
		float4 spotLightColour = calculateSpotLighting(directionFromLight, direction[iterator], newNormal, diffuse[iterator] * attenuationValue) * (1 - direction[iterator].w);

		// Add the two together and multiply by light toggle
		lightingColour[iterator] = (pointLightColour + spotLightColour) * lightPosition[iterator].w;

		// Sample roughness value
		float sampledRoughness = texture3.Sample(sampler0, input.tex).r;

		// Calculate specular lighting
		specularValue[iterator] = calcSpecular(-directionFromLight, newNormal, input.viewVector, specular[iterator].xyz, max(1.0f, sampledRoughness * specular[iterator].w)) * direction[iterator].w;
		specularValue[iterator] = calculateSpecularSpotLighting(directionFromLight, direction[iterator], newNormal, input.viewVector, specular[iterator].xyz, max(1.0f, sampledRoughness * specular[iterator].w)) * (1 - direction[iterator].w);
		
		// ttenuated specular light
		specularValue[iterator] = specularValue[iterator] * (attenuationValue / 2) * lightPosition[iterator].w;
	}

	// Sample occlusion
	float sampledOcclusion = texture2.Sample(sampler0, input.tex).r;

	// Calculate final diffuse lighting colour
	float4 lightingColourFinal = lightingColour[0] + lightingColour[1] + ambient[0];

	// Sample the pixel color from the texture using the sampler at this texture coordinate location.
	return saturate(texture0.Sample(sampler0, input.tex) * lightingColourFinal + specularValue[0] + specularValue[1]) * sampledOcclusion;
}