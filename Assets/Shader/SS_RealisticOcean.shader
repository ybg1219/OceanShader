Shader "Custom/SS_RealisticOcean"
{
	Properties
	{
		[Header(Base Settings)]
		_WaterColor("Shallow Water Color", Color) = (0.5, 0.8, 1, 1)
		_DeepWaterColor("Deep Water Color", Color) = (0.1, 0.2, 0.4, 1)
		_Cube("Skybox Reflect", Cube) = "" {}

		[Header(Depth and Alpha)]
		_DepthRange("Water Depth Range", Range(1, 50)) = 10
		_BaseAlpha("Shallow Alpha", Range(0, 1)) = 0.5

		[Header(Wave Settings)]
		_Amplitude("Wave Amplitude", Range(0, 5)) = 0.5
		_Frequency("Wave Frequency", Range(0, 10)) = 1.0
		_WaveSpeed("Wave Speed", Range(0, 5)) = 1.0

		[Header(Normal and Reflection)]
		_BumpTex("Normal Map", 2D) = "bump" {}
		_BumpSpeed("Normal Scroll Speed", Range(0, 1)) = 0.2
		_Fresnel("Fresnel Power", Range(1, 50)) = 10
		_FresnelOffset("Fresnel Offset", Range(0, 1)) = 0.3

		[Header(Specular Settings)]
		[HDR]_SPColor("Specular Color", Color) = (1,1,1,1)
		_SPPower("Specular Power", Range(50, 300)) = 100
		_SPMulti("Specular Multiply", Range(1, 10)) = 1.0

		[Header(Foam Settings)]
		_FoamTex("Foam Texture", 2D) = "white" {}
		_FoamColor("Foam Color", Color) = (1,1,1,1)
		_FoamTiling("Foam Tiling", Range(1, 10)) = 1
		_FoamThickness("Foam Thickness", Range(0.1, 10)) = 2
	}

		SubShader
		{
			Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
			LOD 200

			CGPROGRAM
			#pragma surface surf Water alpha:blend vertex:vert fullforwardshadows
			#pragma target 3.0

			sampler2D _BumpTex, _FoamTex, _CameraDepthTexture;
			samplerCUBE _Cube;

			struct Input
			{
				float2 uv_BumpTex;
				float2 uv_FoamTex;
				float4 screenPos;
				float3 worldRefl;
				float3 viewDir;
				INTERNAL_DATA
			};

			fixed4 _WaterColor, _DeepWaterColor, _SPColor, _FoamColor;
			half _Fresnel, _FresnelOffset, _SPPower, _SPMulti;
			half _BumpSpeed, _Amplitude, _Frequency, _WaveSpeed;
			half _FoamTiling, _FoamThickness, _DepthRange, _BaseAlpha;

			void vert(inout appdata_full v)
			{
				float time = _Time.y * _WaveSpeed;
				float movement = sin(abs(v.texcoord.x * 2 - 1) * _Frequency + time) * _Amplitude;
				movement += sin(abs(v.texcoord.y * 2 - 1) * _Frequency + time) * _Amplitude;
				v.vertex.y += movement * 0.5;
			}

			void surf(Input IN, inout SurfaceOutput o)
			{
				// 1. 노멀 계산
				float2 normalUV = IN.uv_BumpTex;
				float3 n1 = UnpackNormal(tex2D(_BumpTex, normalUV + _Time.x * _BumpSpeed));
				float3 n2 = UnpackNormal(tex2D(_BumpTex, normalUV - _Time.x * _BumpSpeed));
				o.Normal = normalize(n1 + n2);

				// 2. 프레넬 계산 (Lighting 함수에서 이사 옴)
				// viewDir와 Normal을 사용하여 계산
				float rim = 1.0 - saturate(dot(normalize(IN.viewDir), o.Normal));
				float fresnelFactor = saturate(pow(rim, _Fresnel) + _FresnelOffset);

				// 3. 반사광 가져오기
				fixed4 reflection = texCUBE(_Cube, WorldReflectionVector(IN, o.Normal));

				// 4. 깊이 및 물색 계산
				float rawDepth = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(IN.screenPos)).r;
				float sceneDepth = LinearEyeDepth(rawDepth);
				float waterDepth = sceneDepth - IN.screenPos.w;
				float depthMask = saturate(waterDepth / _DepthRange);
				float4 finalWaterColor = lerp(_WaterColor, _DeepWaterColor, depthMask);

				// 5. 최종 합성 (프레넬 적용!)
				// fresnelFactor가 높을수록(측면) reflection(반사)이 강해지고, 
				// 낮을수록(정면) finalWaterColor(굴절/물색)가 보입니다.
				float3 colorWithRefl = lerp(finalWaterColor.rgb, reflection.rgb, fresnelFactor-0.1);

				// 6. 포말 연산
				float2 foamUV = IN.uv_FoamTex * _FoamTiling + float2(_Time.y, _Time.y * 0.5) * 0.1;
				fixed foamAlpha = tex2D(_FoamTex, foamUV).r;
				float shorelineMask = saturate(waterDepth / _FoamThickness);

				float3 withFoam = lerp(colorWithRefl, _FoamColor.rgb, foamAlpha);
				float3 finalColor = lerp(withFoam, colorWithRefl, shorelineMask);

				o.Emission = finalColor;
				o.Alpha = lerp(foamAlpha, finalWaterColor.a, shorelineMask);
			}

			// Lighting 함수는 이제 스펙큘러와 그림자(atten)에만 집중합니다.
			float4 LightingWater(SurfaceOutput s, float3 lightDir, float3 viewDir, float atten)
			{
				float3 h = normalize(lightDir + viewDir);
				float spec = pow(saturate(dot(s.Normal, h)), _SPPower);

				float4 final;
				// Emission에 이미 조명색이 반영되지 않은 물색이 있으므로 LightColor와 atten을 적절히 섞어줍니다.
				final.rgb = (s.Emission * _LightColor0.rgb * atten) + (spec * _SPColor.rgb * _SPMulti * _LightColor0.rgb * atten);
				final.a = s.Alpha + spec;

				return final;
			}
			ENDCG
		}
			FallBack "Transparent/Cutout/VertexLit"
}