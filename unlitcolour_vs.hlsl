// vertex shader
// Basic shader for rendering unlit coloured geometry

cbuffer MatrixBuffer : register(b0)
{
	matrix worldMatrix;
	matrix viewMatrix;
	matrix projectionMatrix;
};

struct InputType
{
	float4 position : POSITION;
};

struct OutputType
{
	float4 position : SV_POSITION;
};

// Pass everything along very standard
OutputType main(InputType input)
{
	OutputType output;

	output.position = mul(input.position, worldMatrix);
	output.position = mul(output.position, viewMatrix);
	output.position = mul(output.position, projectionMatrix);

	return output;
}