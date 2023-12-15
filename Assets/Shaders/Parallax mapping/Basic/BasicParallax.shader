//Basic parallax shader
Shader "Volume/BasicParallax" 
{
	Properties 
	{
		_NoiseTex("Noise texture", 2D) = "white" {}
	}
	
	SubShader 
	{
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		
		#pragma surface surf Lambert vertex:vert
		#pragma target 3.0


		//Input
		sampler2D _NoiseTex;


		struct Input 
		{
			//What Unity can give you
			float2 uv_NoiseTex;
		
			//What you have to calculate yourself
			//The camera direction in tangent space
			float3 tangentViewDir;
		};


		void vert(inout appdata_full i, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			
			//Calculate the view direction in tangent space from world space			
			float3 worldVertexPos = mul(unity_ObjectToWorld, i.vertex).xyz;
			float3 worldViewDir = worldVertexPos - _WorldSpaceCameraPos;
			
			//To convert from world space to tangent space we need the following
			//https://docs.unity3d.com/Manual/SL-VertexFragmentShaderExamples.html
			float3 worldNormal = UnityObjectToWorldNormal(i.normal);
			float3 worldTangent = UnityObjectToWorldDir(i.tangent.xyz);
			float3 worldBitangent = cross(worldNormal, worldTangent) * i.tangent.w * unity_WorldTransformParams.w;

			//Use dot products instead of building the matrix
			o.tangentViewDir = float3(
				dot(worldViewDir, worldTangent),
				dot(worldViewDir, worldNormal),
				dot(worldViewDir, worldBitangent)
				);
		}


		//Get the height from a uv position
		float getHeight(float2 texturePos)
		{
			//Multiply with 0.2 to get a smoother terrain
			float4 colorNoise = tex2Dlod(_NoiseTex, float4(texturePos * 0.2, 0, 0));

			//Use r because rgb are all the same because color is grayscale
			//This assumes that the depth of the parallax effect is 1 m
			//-1 because the ray is going down so its y-coordinate will be negative
			float height = colorNoise.r * -1;

			return height;
		}


		void surf (Input IN, inout SurfaceOutput o) 
		{
			//Where is the ray starting? y is up and we always start at the surface
			float3 rayPos = float3(IN.uv_NoiseTex.x, 0, IN.uv_NoiseTex.y);

			//What's the direction of the ray?
			float3 rayDir = normalize(IN.tangentViewDir);
			
			//Find where the ray is intersecting with the ground with a raymarch algorithm
			int STEPS = 200;
			float stepDistance = 0.01;

			//The default color used if the ray doesnt hit anything
			float4 finalColor = 1;

			for (int i = 0; i < STEPS; i++)
			{
				//Get the current height at this uv coordinate
				float height = getHeight(rayPos.xz);

				//If the ray is below the surface
				if (rayPos.y < height)
				{
					//The height is negative so make it positive again so we can use the height as color
					finalColor = height * -1;
					
					//Stop the raymarching because we have found ground
					break;
				}
				//The ray is still above the surface
				else
				{
					//Move along the ray
					rayPos += stepDistance * rayDir;
				}

				/*//Make a wall around the hole
				if (rayPos.x > 1 || rayPos.x < 0 || rayPos.z > 1 || rayPos.z < 0)
				{
					break;
				}*/
			}

			//Output
			o.Albedo = finalColor.rgb;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
