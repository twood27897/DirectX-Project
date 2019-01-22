// texture vertex shader
// Basic shader for rendering textured geometry

cbuffer MatrixBuffer : register(b0)
{
	matrix worldMatrix;
	matrix viewMatrix;
	matrix projectionMatrix;
	matrix inverseTransposeWorldMatrix;
};

cbuffer CameraBuffer : register(b1)
{
	float3 cameraPosition;
	float padding;
};

struct InputType
{
	float4 position : POSITION;
	float2 tex : TEXCOORD0;
    float3 normal : NORMAL;
	float3 tangent : TANGENT;
};

struct OutputType
{
	float4 position : SV_POSITION;
	float2 tex : TEXCOORD0;
    float3 normal : NORMAL;
	float3 tangent : TANGENT;
	float3 binormal : BINORMAL;
	float3 worldPosition : TEXCOORD1;
	float3 viewVector : TEXCOORD2;
};

OutputType main(InputType input)
{
	OutputType output;

	// Calculate the position of the vertex against the world, view, and projection matrices.
	output.position = mul(input.position, worldMatrix);
	output.position = mul(output.position, viewMatrix);
	output.position = mul(output.position, projectionMatrix);

	// Store the texture coordinates for the pixel shader.
	output.tex = input.tex;

	// Find binormal from normal and tangent for normal map sampling
    output.normal = input.normal;
	output.tangent = input.tangent;
	output.binormal = normalize(cross(output.normal, output.tangent));

	// Translate to world space
	output.normal = normalize(mul(output.normal, inverseTransposeWorldMatrix));
	output.tangent = normalize(mul(output.tangent, worldMatrix));
	output.binormal = normalize(mul(output.binormal, worldMatrix));

	// Save world position for lighting calculation
	output.worldPosition = mul(input.position, worldMatrix).xyz;

	// Calculate view vector for specular
	output.viewVector = cameraPosition - output.worldPosition.xyz;
	output.viewVector = normalize(output.viewVector);

	return output;
}