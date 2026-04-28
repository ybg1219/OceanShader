Shader "Custom/S_Ocean"
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
		_Speed("Normal Scroll Speed", Range(0, 1)) = 0.2
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
		_FoamThickness("Foam Thickness", Range(0.01, 2)) = 0.1
	}

		SubShader
		{
			Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
			LOD 200

			CGPROGRAM
			#pragma surface surf Water alpha:blend vertex:vert
			#pragma target 3.0

			sampler2D _BumpTex, _FoamTex, _CameraDepthTexture;
			samplerCUBE _Cube;

			struct Input
			{
				float2 uv_BumpTex;
				float2 uv_FoamTex;
				float4 screenPos;
				float3 worldRefl;
				INTERNAL_DATA
			};

			fixed4 _WaterColor, _DeepWaterColor, _SPColor, _FoamColor;
			half _Fresnel, _FresnelOffset, _SPPower, _SPMulti;
			half _Speed, _Amplitude, _Frequency, _WaveSpeed;
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
				// 1. 노멀 및 반사
				float2 normalUV = IN.uv_BumpTex;
				float3 n1 = UnpackNormal(tex2D(_BumpTex, normalUV + _Time.x * _Speed));
				float3 n2 = UnpackNormal(tex2D(_BumpTex, normalUV - _Time.x * _Speed));
				o.Normal = normalize(n1 + n2);
				fixed4 reflection = texCUBE(_Cube, WorldReflectionVector(IN, o.Normal));

				// 2. 깊이 계산
				float rawDepth = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(IN.screenPos)).r;
				float sceneDepth = LinearEyeDepth(rawDepth);
				float waterDepth = sceneDepth - IN.screenPos.w; // 실제 수심

				// 3. 수심에 따른 색상 및 투명도 결정
				// 깊을수록 1에 가까워짐
				float depthMask = saturate(waterDepth / _DepthRange);
				// 얕은 곳은 _WaterColor, 깊은 곳은 _DeepWaterColor
				float4 finalWaterColor = lerp(_WaterColor, _DeepWaterColor, depthMask);

				// 4. 포말 연산 (아주 얕은 곳)
				float2 foamUV = IN.uv_FoamTex * _FoamTiling + float2(_Time.y, _Time.y * 0.5) * 0.1;
				fixed foamAlpha = tex2D(_FoamTex, foamUV).r;
				float shorelineMask = saturate(waterDepth * _FoamThickness); // 0(해안선) ~ 1(바다)

				// 5. 최종 합성
				// 수면 색상 + 반사광을 기본으로 하고, 해안가에 포말 추가
				float3 colorWithRefl = lerp(finalWaterColor.rgb, reflection.rgb, 0.5); // 반사 살짝 섞음
				float3 withFoam = lerp(colorWithRefl , _FoamColor.rgb, foamAlpha);
				float3 finalColor = lerp(withFoam, colorWithRefl, shorelineMask);

				o.Emission = finalColor;
				// 깊을수록 더 불투명해지도록 설정 (ShallowAlpha ~ 1.0)
				o.Alpha = lerp(foamAlpha, finalWaterColor.a, shorelineMask);
			}

			float4 LightingWater(SurfaceOutput s, float3 lightDir, float3 viewDir, float atten)
			{
				float3 h = normalize(lightDir + viewDir);
				float spec = pow(saturate(dot(s.Normal, h)), _SPPower);

				float rim = 1.0 - saturate(dot(viewDir, s.Normal));
				rim = pow(rim, _Fresnel) + _FresnelOffset;

				float4 final;
				final.rgb = spec * _SPColor.rgb * _SPMulti * _LightColor0.rgb * atten;
				final.a = s.Alpha + spec; // 스펙큘러 부분은 더 불투명하게

				return final;
			}
			ENDCG
		}
			FallBack "Legacy Shaders/Transparent/Vertexlit"
}