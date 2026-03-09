Shader "Custom/S_StylizedOcean"
{
	Properties
	{
		[Header(Base Water Settings)]
		_WaterColor("Water Color", Color) = (1,1,1,1)
		_FresnelColor("Fresnel Color", Color) = (1,1,1,1)
		_FresnelPower("Fresnel Power", Range(1,50)) = 30
		_FresnelOffset("Fresnel Offset", Range(0,1)) = 0.3

		[Header(Specular Settings)]
		_SpecularColor("Specular Color", Color) = (1,1,1,1)
		_SpecularPower("Specular Power", Range(50,300)) = 50

		[Header(Wave Settings)]
		_WaveAmplitude("Wave Amplitude", Range(1,30)) = 1.0
		_WaveFrequency("Wave Frequency", Range(1,10)) = 1.0
		_WaveTime("Wave Time", Range(1,10)) = 1.0

		[Header(Shoreline Foam)]
		_ShorelineFoamTex("Shoreline Foam Texture", 2D) = "white"{}
		_ShorelineFoamColor("Shoreline Foam Color", Color) = (1,1,1,1)
		_ShorelineFoamTiling("Shoreline Foam Tiling", Range(1,10)) = 1
		_ShorelineFoamThickness("Shoreline Foam Thickness", Range(1,10)) = 0.1
		_ShorelineFoamSpeed("Shoreline Foam Speed", Range(0,1)) = 0.1

		[Header(Floating Foam)]
		_FloatingFoamPos("Floating Foam Position (Mask)", 2D) = "white"{}
		_FloatingFoamTex("Floating Foam Texture", 2D) = "white"{}
		_FloatingFoamColor("Floating Foam Color", Color) = (1,1,1,1)
		_FloatingFoamTiling("Floating Foam Tiling", Range(1,10)) = 1
		_FloatingFoamThickness("Floating Foam Thickness", Range(0.01,2)) = 0.1
		_FloatingFoamSpeed("Floating Foam Speed", Range(0.1,1)) = 0.1
	}
		SubShader
		{
			Tags { "RenderType" = "Transparent" "Queue" = "Transparent"}
			LOD 200

			CGPROGRAM
				#pragma surface surf Water alpha:blend vertex:vert
				#pragma target 4.0

				sampler2D _ShorelineFoamTex;
				sampler2D _CameraDepthTexture;
				sampler2D _FloatingFoamPos;
				sampler2D _FloatingFoamTex;

				struct Input
				{
					float2 uv_ShorelineFoamTex;
					float2 uv_FloatingFoamPos;
					float2 uv_FloatingFoamTex;
					float4 screenPos;
					float3 worldRefl;
					float3 worldPos;
					INTERNAL_DATA
				};

				float4 _WaterColor;
				float4 _FresnelColor;
				float _FresnelPower;
				float _FresnelOffset;

				float4 _SpecularColor;
				float _SpecularPower;

				float4 _ShorelineFoamColor;
				float _ShorelineFoamTiling;
				float _ShorelineFoamThickness;
				float _ShorelineFoamSpeed;

				float4 _FloatingFoamColor;
				float _FloatingFoamTiling;
				float _FloatingFoamThickness;
				float _FloatingFoamSpeed;

				float _WaveTime;
				float _WaveFrequency;
				float _WaveAmplitude;

				UNITY_INSTANCING_BUFFER_START(Props)
				UNITY_INSTANCING_BUFFER_END(Props)

				void vert(inout appdata_full v)
				{
					float movement;
					movement = sin(abs(v.texcoord.x * 2 - 1) * _WaveFrequency + _Time.y * _WaveTime) * _WaveAmplitude;
					movement += sin(abs(v.texcoord.y * 2 - 1) * _WaveFrequency + _Time.y * _WaveTime) * _WaveAmplitude;
					v.vertex.y += movement*0.5;
				}

				void surf(Input IN, inout SurfaceOutput o)
				{
					// Shoreline Foam 연산
					float shorelineMask = tex2D(_ShorelineFoamTex, IN.uv_ShorelineFoamTex * _ShorelineFoamTiling + float2(_Time.y, _Time.y / 2) * _ShorelineFoamSpeed).r;

					// Floating Foam 연산
					float2 timeOffset = float2(_Time.y, _Time.y / 2) * _FloatingFoamSpeed;

					// 레이어 1
					float4 floatingPos = tex2D(_FloatingFoamPos, IN.uv_FloatingFoamPos * _FloatingFoamTiling + timeOffset);
					// 레이어 2 (다른 스케일과 반대 방향 속도)
					float4 floatingPos2 = tex2D(_FloatingFoamPos, IN.uv_FloatingFoamPos * (_FloatingFoamTiling * 1.73) - timeOffset * 0.8); 
					float4 floatingTex = tex2D(_FloatingFoamTex, IN.uv_FloatingFoamTex * _FloatingFoamTiling + timeOffset);

					// Depth 기반 Shoreline 영역 정의
					float depth = LinearEyeDepth(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(IN.screenPos)).r);
					float shorelineArea = saturate((depth - IN.screenPos.w) / _ShorelineFoamThickness);

					float3 shorelineFoam = saturate(_ShorelineFoamColor.rgb * shorelineMask);
					
					// 1. 두 레이어를 곱해 기초 교집합 생성
					float combinedMask = floatingPos.r * floatingPos2.r;

					// 2. 시간에 따른 유기적인 임계값 (Threshold) 애니메이션
					// 거품이 한 번에 나타나지 않고 위치마다 다르게 나타나게 함
					float animatedThreshold = saturate(sin(_Time.y * 0.8) * 0.5 + 0.5) * 0.2;

					// 3. Smoothstep을 사용하여 도장 느낌 제거
					// 임계값보다 높은 부분은 남기고, 경계는 부드럽게 처리
					float finalMask = smoothstep(animatedThreshold, animatedThreshold+0.2, combinedMask);

					// 4. 최종 알파 적용
					floatingPos.a *= finalMask;

					float3 floatingFoam = floatingTex.rgb * _FloatingFoamColor.rgb * floatingPos.a;

					// 최종 색상 혼합 (기존 로직 유지)
					o.Emission = _WaterColor.rgb + lerp(shorelineFoam, floatingFoam, shorelineArea);
				}

				float4 LightingWater(SurfaceOutput s, float3 lightDir, float3 viewDir, float atten) {
					// Specular
					float3 h = normalize(lightDir + viewDir);
					float spec = saturate(dot(s.Normal, h));
					spec = pow(spec, _SpecularPower);

					// Rim (Fresnel)
					float rim = saturate(dot(viewDir, s.Normal));
					rim = saturate(pow(1 - rim, _FresnelPower) + _FresnelOffset);

					// 기존의 반전된 Fresnel 색상 혼합 유지
					float3 water = lerp(float3(0, 0, 0), _FresnelColor.rgb - s.Emission, rim);

					float4 final;
					final.rgb = water;
					final.a = 1;
					return final;
				}

			ENDCG
		}
			FallBack "Legacy Shaders/Transparent/Vertexlit"
}