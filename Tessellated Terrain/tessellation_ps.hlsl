// Tessellation pixel shader
// Output colour passed to stage.

Texture2D texture0 : register(t0);
Texture2D texture1 : register(t1);
Texture2D texture2 : register(t2);
Texture2D texture3 : register(t3);
SamplerState sampler0 : register(s0);
SamplerState sampler1 : register(s1);

cbuffer LightBufferType : register(b0)
{
	float4 ambient[2];
	float4 diffuse[2];
	float4 direction[2];
	float4 lightPosition[2];
};

struct InputType
{
    float4 position : SV_POSITION;
	float2 tex : TEXCOORD0;
	float2 tex2 : TEXCOORD1;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
	float3 binormal : BINORMAL;
	float4 lightViewPos : TEXCOORD2;
	float4 lightViewPos2 : TEXCOORD3;
	float3 worldPosition : TEXCOORD4;
};

// Attenuation calculation
float calculateAttenuation(float distance, float constantFactor, float linearFactor, float quadraticFactor)
{
	float attenuation = 1.0f / (constantFactor + (linearFactor * distance) + (quadraticFactor * pow(distance, 2)));
	return attenuation;
}

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

int calculateDepthFromLight(float4 lightViewPos, float4 textureColour, float shadowMapBias, Texture2D depthMapTexture)
{
	// Initialise depth values
	float depthMapValue = 0;
	float currentDepthValue = 0;

	// Calculate the projected texture coordinates of the pixel
	float2 pTexCoord = lightViewPos.xy / lightViewPos.w;
	pTexCoord *= float2(0.5, -0.5);
	pTexCoord += float2(0.5f, 0.5f);

	// Sample the shadow map (get depth of geometry)
	depthMapValue = depthMapTexture.Sample(sampler1, pTexCoord).r;

	// Calculate the depth from the light.
	currentDepthValue = lightViewPos.z / lightViewPos.w;
	currentDepthValue -= shadowMapBias;

	// If depth map value is greater than current depth from light return 1 if its less than return 0
	return currentDepthValue < depthMapValue ? 1 : 0;
}

float4 main(InputType input) : SV_TARGET
{
	// Sample initial texture colour
	float4 textureColour = texture0.Sample(sampler0, input.tex2);
	float4 colour = float4(0.0f, 0.0f, 0.0f, 1.0f);

	// Find normal from normal map
	float4 sampledNormal = normalize(texture1.Sample(sampler0, input.tex) - float4(0.5f, 0.5f, 0.5f, 0.0f));
	float3 newNormal = input.normal + (sampledNormal.x * input.tangent + sampledNormal.y * input.binormal);
	newNormal = normalize(newNormal);

	// Initialise required shadow variables
	int shadowed[2];
	shadowed[0] = 1;
	shadowed[1] = 1;
	float shadowMapBias = 0.005;

	// Light 1
	// Calculate the projected texture coordinates.
	float2 pTexCoord = input.lightViewPos.xy / input.lightViewPos.w;
	pTexCoord *= float2(0.5, -0.5);
	pTexCoord += float2(0.5f, 0.5f);

	// Determine if the projected coordinates are in the 0 to 1 range and check for shadow if so
	if ((pTexCoord.x < 0.f || pTexCoord.x > 1.f || pTexCoord.y < 0.f || pTexCoord.y > 1.f) == false)
	{
		shadowed[0] = calculateDepthFromLight(input.lightViewPos, textureColour, shadowMapBias, texture2);
	}

	// Light 2
	// Calculate the projected texture coordinates.
	float2 pTexCoord2 = input.lightViewPos2.xy / input.lightViewPos2.w;
	pTexCoord2 *= float2(0.5, -0.5);
	pTexCoord2 += float2(0.5f, 0.5f);

	// Determine if the projected coordinates are in the 0 to 1 range and check for shadow if so
	if ((pTexCoord2.x < 0.f || pTexCoord2.x > 1.f || pTexCoord2.y < 0.f || pTexCoord2.y > 1.f) == false)
	{
		shadowed[1] = calculateDepthFromLight(input.lightViewPos2, textureColour, shadowMapBias, texture3);
	}

	// Loop per light
	float4 lightingColour[2];
	for (int iterator = 0; iterator < 2; iterator++)
	{
		// Calculate attenuation
		float vertexToLightDistance = distance(lightPosition[iterator].xyz, input.worldPosition);
		float attenuationValue = calculateAttenuation(vertexToLightDistance, 0.5f, 0.125f, 0.05f);

		// Find direction between pixel and light
		float3 directionFromLight = normalize(input.worldPosition - lightPosition[iterator].xyz);

		// Point light effect on pixel
		float4 pointLightColour = calculateLighting(-directionFromLight, newNormal, diffuse[iterator] * attenuationValue) * shadowed[iterator] * direction[iterator].w;

		// Spotlight effect on pixel
		float4 spotLightColour = calculateSpotLighting(directionFromLight, direction[iterator], newNormal, diffuse[iterator] * attenuationValue) * shadowed[iterator] * (1 - direction[iterator].w);

		// Find final colour and multiply by light toggle
		lightingColour[iterator] = (pointLightColour + spotLightColour) * lightPosition[iterator].w;
	}

	// Add light effects and ambient together
	float4 lightingColourFinal = lightingColour[0] * lightPosition[0].w + lightingColour[1] * lightPosition[1].w + ambient[0];

	return (textureColour * saturate(lightingColourFinal));
}