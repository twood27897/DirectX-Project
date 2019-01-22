// pixel/fragment shader
// Basic fragment shader for rendering unlit coloured geometry

struct InputType
{
	float4 position : SV_POSITION;
};

float4 main(InputType input) : SV_TARGET
{
	// Return white
	return float4(1.0f, 1.0f, 1.0f, 1.0f);
}