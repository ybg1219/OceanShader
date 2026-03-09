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
				float _WaterFrequency;
				float _WaveAmplitude;

				UNITY_INSTANCING_BUFFER_START(Props)
				UNITY_INSTANCING_BUFFER_END(Props)

				void vert(inout appdata_full v)
				{
					float movement;
					movement = sin(abs(v.texcoord.x * 2 - 1) * _WaterFrequency + _Time.y * _WaveTime) * _WaveAmplitude;
					movement += sin(abs(v.texcoord.y * 2 - 1) * _WaterFrequency + _Time.y * _WaveTime) * _WaveAmplitude;
					v.vertex.y += movement*0.5;
				}

				void surf(Input IN, inout SurfaceOutput o)
				{
					// Shoreline Foam 연산
					float shorelineMask = tex2D(_ShorelineFoamTex, IN.uv_ShorelineFoamTex * _ShorelineFoamTiling + float2(_Time.y, _Time.y / 2) * _ShorelineFoamSpeed).r;

					// Floating Foam 연산
					float4 floatingPos = tex2D(_FloatingFoamPos, IN.uv_FloatingFoamPos * _FloatingFoamTiling + float2(_Time.y, _Time.y / 2) * _FloatingFoamSpeed);
					float4 floatingTex = tex2D(_FloatingFoamTex, IN.uv_FloatingFoamTex * _FloatingFoamTiling + float2(_Time.y, _Time.y / 2) * _FloatingFoamSpeed);

					// Depth 기반 Shoreline 영역 정의
					float depth = LinearEyeDepth(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(IN.screenPos)).r);
					float shorelineArea = saturate((depth - IN.screenPos.w) / _ShorelineFoamThickness);

					float3 shorelineFoam = saturate(_ShorelineFoamColor.rgb * shorelineMask);

					// 기존 sf.a 조건부 로직 유지
					floatingPos.a = floatingPos.r >= 0.5 ? saturate(sin(_Time.y)) * floatingPos.a : 0;
					float3 floatingFoam = floatingTex.rgb *_FloatingFoamColor * floatingPos.a;

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