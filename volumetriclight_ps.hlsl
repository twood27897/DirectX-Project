// Light pixel shader
// Calculate volumetric lighting on render texture

Texture2D texture0 : register(t0);
Texture2D texture1 : register(t1);
SamplerState sampler0 : register(s0);

cbuffer MatrixBuffer : register(b0)
{
	matrix worldMatrix;
	matrix viewMatrix;
	matrix projectionMatrix;
};

cbuffer LightBuffer : register(b1)
{
	float4 ambient;
	float4 diffuse;
	float3 position;
	float padding;
};

// Pass in variables to play with rays
cbuffer RaysBuffer : register(b2)
{
	float passedNumberOfSamples;
	float passedDensity;
	float passedDecayRate;
	float passedExposure;
};


struct InputType
{
	float4 position : SV_POSITION;
	float2 tex : TEXCOORD0;
	float3 normal : NORMAL;
	float3 worldPosition : TEXCOORD1;
};

// Equation for volumetric light scattering
float4 volumetricLightScattering(float2 texCoord, int numberOfSamples, float density, float decayRate, float weight, float exposure)
{
	// Calculate the lights position on the screen
	float4 lightScreenPosition;
	lightScreenPosition = mul(float4(position, 1.0f), viewMatrix);
	lightScreenPosition = mul(lightScreenPosition, projectionMatrix);
	lightScreenPosition.xyz /= lightScreenPosition.w;
	lightScreenPosition.xy *= float2(0.5f, -0.5f);
	lightScreenPosition.xy += 0.5f;

	// Find vector between light and current pixel on the screen
	float2 raycastLightToPixel = texCoord - lightScreenPosition.xy;

	// Calculate the increment for the texture coord
	float2 incrementPerSample = raycastLightToPixel / (numberOfSamples * density);

	// Sample the intial colour at the texture coordinate
	float4 initialColourSample = texture0.Sample(sampler0, texCoord);
	float2 currentTexCoord = texCoord;

	float illuminationDecay = 1.0f; 

	// For the number of samples
	for (int i = 0; i < numberOfSamples; i++)
	{
		// Find new texture coord and colour at current sample point
		currentTexCoord -= incrementPerSample;
		currentTexCoord = saturate(currentTexCoord);
		float4 currentColourSample = texture0.Sample(sampler0, currentTexCoord);

		// Apply attenuation/decay
		currentColourSample *= illuminationDecay * weight;

		// Add to combined colour
		initialColourSample += currentColourSample;

		// Update decay to decrease
		illuminationDecay *= decayRate;
	}

	return initialColourSample * exposure;
}

float4 main(InputType input) : SV_TARGET
{
	// Calculate volumetric light scattering
	float4 rayColour = volumetricLightScattering(input.tex, (int)passedNumberOfSamples, passedDensity, passedDecayRate, 0.58767f, passedExposure);
	rayColour.a = 1.0f;

	// Sample main scene render
	float4 mainColour = texture1.Sample(sampler0, input.tex);

	// Additively blend the two colours
	return saturate(rayColour + mainColour);
}