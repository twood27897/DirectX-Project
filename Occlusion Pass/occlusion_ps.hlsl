// Light pixel shader
// Calculate diffuse lighting for a single directional light (also texturing)
// Render everything in black

struct InputType
{
	float4 position : SV_POSITION;
	float2 tex : TEXCOORD0;
	float3 normal : NORMAL;
};

// Calculate lighting intensity based on direction and normal. Combine with light colour.
float4 calculateLighting(float3 lightDirection, float3 normal, float4 ldiffuse)
{
	float intensity = saturate(dot(normal, lightDirection));
	float4 colour = saturate(ldiffuse * intensity);
	return colour;
}



float4 main(InputType input) : SV_TARGET
{
	// Render geometry black
	return float4(0.0f, 0.0f, 0.0f, 1.0f);
}