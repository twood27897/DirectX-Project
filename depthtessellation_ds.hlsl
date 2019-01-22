// Tessellation domain shader
// After tessellation the domain shader processes the all the vertices

Texture2D texture0 : register(t0);
SamplerState sampler0 : register(s0);

cbuffer MatrixBuffer : register(b0)
{
    matrix worldMatrix;
    matrix viewMatrix;
    matrix projectionMatrix;
	matrix inverseTransposeWorldMatrix;
};

struct ConstantOutputType
{
    float edges[4] : SV_TessFactor;
    float inside[2] : SV_InsideTessFactor;
};

struct InputType
{
    float3 position : POSITION;
	float2 tex : TEXCOORD0;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
};

struct OutputType
{
    float4 position : SV_POSITION;
	float4 depthPosition :TEXCOORD0;
};

[domain("quad")]
OutputType main(ConstantOutputType input, float2 uvwCoord : SV_DomainLocation, const OutputPatch<InputType, 4> patch)
{
    float3 vertexPosition;
    OutputType output;
 
    // Determine the position of the new vertex.
	// Invert the y and Z components of uvwCoord as these coords are generated in UV space and therefore y is positive downward.
	float3 v1 = lerp(patch[0].position, patch[1].position, uvwCoord.y);
	float3 v2 = lerp(patch[3].position, patch[2].position, uvwCoord.y);
	vertexPosition = lerp(v1, v2, uvwCoord.x);

	// Send the input color into the pixel shader.
	float2 uv1 = lerp(patch[0].tex, patch[1].tex, uvwCoord.y);
	float2 uv2 = lerp(patch[3].tex, patch[2].tex, uvwCoord.y);
	float2 tex = lerp(uv1, uv2, uvwCoord.x);

	// Sample displacement map
	vertexPosition.y = texture0.SampleLevel(sampler0, tex, 0.0f).r;

    // Calculate the position of the new vertex against the world, view, and projection matrices.
    output.position = mul(float4(vertexPosition, 1.0f), worldMatrix);
    output.position = mul(output.position, viewMatrix);
    output.position = mul(output.position, projectionMatrix);

	output.depthPosition = output.position;

	// Calculate the normal, tangent and binormal based on texture coordinates of point
	float3 n1 = lerp(patch[0].normal, patch[1].normal, uvwCoord.y);
	float3 n2 = lerp(patch[3].normal, patch[2].normal, uvwCoord.y);
	float3 normal = lerp(n1, n2, uvwCoord.x);

	float3 t1 = lerp(patch[0].tangent, patch[1].tangent, uvwCoord.y);
	float3 t2 = lerp(patch[3].tangent, patch[2].tangent, uvwCoord.y);
	float3 tangent = lerp(t1, t2, uvwCoord.x);

	float3 binormal = normalize(cross(normal, tangent));

	// Change the normal, tangent and binormal from tangent to world space
	normal = normalize(mul(normal, inverseTransposeWorldMatrix));

	tangent = normalize(mul(tangent, worldMatrix));

	binormal = normalize(mul(binormal, worldMatrix));

    return output;
}