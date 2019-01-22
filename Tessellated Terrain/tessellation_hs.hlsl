// Tessellation Hull Shader
// Prepares control points for tessellation

// Displacement texture
Texture2D texture0 : register(t0);
SamplerState sampler0 : register(s0);

// Matrices for normal mapping
cbuffer MatrixBuffer : register(b0)
{
	matrix worldMatrix;
	matrix viewMatrix;
	matrix projectionMatrix;
	matrix inverseTransposeWorldMatrix;
	matrix lightViewMatrix;
	matrix lightProjectionMatrix;
};

// All variables required for dynamic tessellation
cbuffer TesselationBuffer : register(b1)
{
	float tessellationFactor;
	float3 cameraPosition;
	float minimumDistance;
	float maximumDistance;
	float minimumLevelOfDetail;
	float maximumLevelOfDetail;
};

struct InputType
{
    float3 position : POSITION;
	float2 tex : TEXCOORD0;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
};

struct ConstantOutputType
{
    float edges[4] : SV_TessFactor;
    float inside[2] : SV_InsideTessFactor;
};

struct OutputType
{
    float3 position : POSITION;
	float2 tex : TEXCOORD0;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
};

// Average the midpoint of a quad from its four corners
float3 QuadMidPoint(float3 controlPoint1, float3 controlPoint2, float3 controlPoint3, float3 controlPoint4);

// Find normalized distance from camera between min and max distance
float NormalizedDistanceFromCamera(float3 cameraPosition, float3 quadMidPoint);

// Find quad level of detail
float QuadLevelOfDetail(float3 quadMidPoint);

// Find displacement for quad midpoint to incorporate in tessellation calculation
float CalculateMidpointDisplacement(float2 uv0, float2 uv1, float2 uv2, float2 uv3);

ConstantOutputType PatchConstantFunction(InputPatch<InputType, 12> inputPatch, uint patchId : SV_PrimitiveID)
{    
    ConstantOutputType output;

	// Calculate midpoints for all quads in patch
	float3 midPoints[5];

	// Main quad
	midPoints[0] = QuadMidPoint(inputPatch[0].position, inputPatch[1].position, inputPatch[2].position, inputPatch[3].position);

	// Right quad
	midPoints[1] = QuadMidPoint(inputPatch[1].position, inputPatch[2].position, inputPatch[4].position, inputPatch[5].position);

	// Front quad
	midPoints[2] = QuadMidPoint(inputPatch[2].position, inputPatch[3].position, inputPatch[6].position, inputPatch[7].position);

	// Left quad
	midPoints[3] = QuadMidPoint(inputPatch[0].position, inputPatch[3].position, inputPatch[8].position, inputPatch[9].position);

	// Back quad
	midPoints[4] = QuadMidPoint(inputPatch[0].position, inputPatch[1].position, inputPatch[10].position, inputPatch[11].position);

	// Displace mid points with height map
	midPoints[0].y = CalculateMidpointDisplacement(inputPatch[0].tex, inputPatch[1].tex, inputPatch[2].tex, inputPatch[3].tex);
	midPoints[1].y = CalculateMidpointDisplacement(inputPatch[1].tex, inputPatch[2].tex, inputPatch[4].tex, inputPatch[5].tex);
	midPoints[2].y = CalculateMidpointDisplacement(inputPatch[2].tex, inputPatch[3].tex, inputPatch[6].tex, inputPatch[7].tex);
	midPoints[3].y = CalculateMidpointDisplacement(inputPatch[0].tex, inputPatch[3].tex, inputPatch[8].tex, inputPatch[9].tex);
	midPoints[4].y = CalculateMidpointDisplacement(inputPatch[0].tex, inputPatch[1].tex, inputPatch[10].tex, inputPatch[11].tex);

	// Translate to world space
	float4 worldMidPoints[5];
	for (int iterator = 0; iterator < 5; iterator++)
	{
		worldMidPoints[iterator] = mul(float4(midPoints[iterator], 1.0f), worldMatrix);
	}

	// Calculate level of detail on all quads
	float levelsOfDetail[5];

	levelsOfDetail[0] = QuadLevelOfDetail(worldMidPoints[0]);
	levelsOfDetail[1] = QuadLevelOfDetail(worldMidPoints[1]);
	levelsOfDetail[2] = QuadLevelOfDetail(worldMidPoints[2]);
	levelsOfDetail[3] = QuadLevelOfDetail(worldMidPoints[3]);
	levelsOfDetail[4] = QuadLevelOfDetail(worldMidPoints[4]);

	// Set the factor for tessallating inside the main quad.
	output.inside[0] = levelsOfDetail[0];
	output.inside[1] = levelsOfDetail[0];

    // Set the tessellation factors for the four edges of the main quad.
	output.edges[0] = min(levelsOfDetail[0], levelsOfDetail[4]);
	output.edges[1] = min(levelsOfDetail[0], levelsOfDetail[3]);
	output.edges[2] = min(levelsOfDetail[0], levelsOfDetail[2]);
	output.edges[3] = min(levelsOfDetail[0], levelsOfDetail[1]);

    return output;
}


[domain("quad")]
[partitioning("fractional_odd")]
[outputtopology("triangle_ccw")]
[outputcontrolpoints(4)]
[patchconstantfunc("PatchConstantFunction")]
OutputType main(InputPatch<InputType, 12> patch, uint pointId : SV_OutputControlPointID, uint patchId : SV_PrimitiveID)
{
    OutputType output;

    // Set the position for this control point as the output position.
    output.position = patch[pointId].position;

    // Set the input texture coordinates as the output texture coordinates.
	//output.colour = (pointId / 4.0f);
	output.tex = patch[pointId].tex;

	output.normal = patch[pointId].normal;

	output.tangent = patch[pointId].tangent;

    return output;
}

// Average four points to find midpoint
float3 QuadMidPoint(float3 controlPoint1, float3 controlPoint2, float3 controlPoint3, float3 controlPoint4)
{
	return (controlPoint1 + controlPoint2 + controlPoint3 + controlPoint4) / 4.0f;
}

// Find normalized distance between min and max tessellation distance
float NormalizedDistanceFromCamera(float3 cameraPosition, float3 quadMidPoint)
{
	float distanceBetween = pow((quadMidPoint - cameraPosition).x, 2) + pow((quadMidPoint - cameraPosition).y, 2) + pow((quadMidPoint - cameraPosition).z, 2);
	distanceBetween = sqrt(distanceBetween);

	return clamp(distanceBetween, minimumDistance, maximumDistance) / maximumDistance;
}

// Find level of detail for a quad
float QuadLevelOfDetail(float3 quadMidPoint)
{
	float normalizedDistance = NormalizedDistanceFromCamera(cameraPosition, quadMidPoint);

	// For max distance we want less detail and vice versa 
	return lerp(minimumLevelOfDetail, maximumLevelOfDetail, 1.0f - normalizedDistance);
}

// Calculate midpoint displacement for a quad
float CalculateMidpointDisplacement(float2 uv0, float2 uv1, float2 uv2, float2 uv3)
{
	float2 uv4 = lerp(uv0, uv1, 0.5f);
	float2 uv5 = lerp(uv3, uv2, 0.5f);
	float2 texCoord = lerp(uv4, uv5, 0.5f);

	return texture0.SampleLevel(sampler0, texCoord, 0.0f);
}