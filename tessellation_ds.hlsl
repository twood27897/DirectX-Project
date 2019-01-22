// Tessellation domain shader
// After tessellation the domain shader processes all the vertices

// Displacement texture and sampler
Texture2D texture0 : register(t0);
SamplerState sampler0 : register(s0);

// All required matrices
cbuffer MatrixBuffer : register(b0)
{
    matrix worldMatrix;
    matrix viewMatrix;
    matrix projectionMatrix;
	matrix inverseTransposeWorldMatrix;
	matrix lightViewMatrix;
	matrix lightProjectionMatrix;
	matrix lightViewMatrix2;
	matrix lightProjectionMatrix2;
};

// Values to tessellate by
struct ConstantOutputType
{
    float edges[4] : SV_TessFactor;
    float inside[2] : SV_InsideTessFactor;
};

// Tangent required for normal map sampling
struct InputType
{
    float3 position : POSITION;
	float2 tex : TEXCOORD0;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
};

// Output everything
struct OutputType
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
	output.tex = tex;

	float2 uv3 = lerp(float2(0.0f, 0.0f), float2(0.0f, 1.0f), uvwCoord.y);
	float2 uv4 = lerp(float2(1.0f, 0.0f), float2(1.0f, 1.0f), uvwCoord.y);
	output.tex2 = lerp(uv3, uv4, uvwCoord.x);

	// Sample displacement map large displacement map
	vertexPosition.y = texture0.SampleLevel(sampler0, tex, 0.0f).r;

	// Save world position of vertex for use in lighting calculations
	output.worldPosition = mul(float4(vertexPosition, 1.0f), worldMatrix).xyz;

	// Calculate the normal, tangent and binormal based on texture coordinates of point
	float3 n1 = lerp(patch[0].normal, patch[1].normal, uvwCoord.y);
	float3 n2 = lerp(patch[3].normal, patch[2].normal, uvwCoord.y);
	output.normal = lerp(n1, n2, uvwCoord.x);

	float3 t1 = lerp(patch[0].tangent, patch[1].tangent, uvwCoord.y);
	float3 t2 = lerp(patch[3].tangent, patch[2].tangent, uvwCoord.y);
	output.tangent = lerp(t1, t2, uvwCoord.x);

	output.binormal = normalize(cross(output.normal, output.tangent));

	// Change the normal, tangent and binormal from tangent to world space
	output.normal = normalize(mul(output.normal, inverseTransposeWorldMatrix));

	output.tangent = normalize(mul(output.tangent, worldMatrix));

	output.binormal = normalize(mul(output.binormal, worldMatrix));

	// Calculate the position of the new vertex against the world, view, and projection matrices.
	output.position = mul(float4(vertexPosition, 1.0f), worldMatrix);
	output.position = mul(output.position, viewMatrix);
	output.position = mul(output.position, projectionMatrix);

	// Calculate the position of the new vertex as viewed by the light
	output.lightViewPos = mul(float4(vertexPosition, 1.0f), worldMatrix);
	output.lightViewPos = mul(output.lightViewPos, lightViewMatrix);
	output.lightViewPos = mul(output.lightViewPos, lightProjectionMatrix);

	// Calculate the position of the new vertex as viewed by the light
	output.lightViewPos2 = mul(float4(vertexPosition, 1.0f), worldMatrix);
	output.lightViewPos2 = mul(output.lightViewPos2, lightViewMatrix2);
	output.lightViewPos2 = mul(output.lightViewPos2, lightProjectionMatrix2);

    return output;
}