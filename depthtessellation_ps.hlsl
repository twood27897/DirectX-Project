// Tessellation pixel shader
// Output colour passed to stage.
struct InputType
{
    float4 position : SV_POSITION;
	float4 depthPosition : TEXCOORD0;
};

float4 main(InputType input) : SV_TARGET
{
	// Get the depth value of the pixel by dividing the Z pixel depth by the homogeneous W coordinate.
	float depthValue;
	depthValue = input.depthPosition.z / input.depthPosition.w;

	return float4(depthValue, depthValue, depthValue, 1.0f);
}