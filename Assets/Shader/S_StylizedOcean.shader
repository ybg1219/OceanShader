Shader "Custom/S_StylizedOcean"
{
	Properties
	{
		[Header(Base Water Settings)]
		_WaterColor("Water Color", Color) = (1,1,1,1)
		_DeepWaterColor("Deep Water Color", Color) = (1,1,1,1)
		_FresnelColor("Fresnel Color", Color) = (1,1,1,1)
		_FresnelPower("Fresnel Power", Range(1,50)) = 30
		_FresnelOffset("Fresnel Offset", Range(0,1)) = 0.3

		[Header(Specular Settings)]
		_BumpTex("BumpMap", 2D) = "bump" {}
		_BumpSpeed("Bump Speed", Range(0,1)) = 0.1
		[HDR]_SpecularColor("Specular Color", Color) = (1,1,1,1)
		_SpecularPower("Specular Power", Range(50,300)) = 50

		[Header(Wave Settings)]
		_WaveAmplitude("Wave Amplitude", Range(1,30)) = 1.0
		_WaveFrequency("Wave Frequency", Range(1,10)) = 1.0
		_WaveTime("Wave Time", Range(1,10)) = 1.0

		[Header(Shoreline Foam)]
		_ShorelineFoamTex("Shoreline Foam Texture", 2D) = "white"{}
		_ShorelineColor("Shoreline Color", Color) = (1,1,1,1)
		_ShorelineFoamColor("Shoreline Foam Color", Color) = (1,1,1,1)
		_ShorelineFoamTiling("Shoreline Foam Tiling", Range(1,10)) = 1

		_ShorelineDefaultThickness("Shoreline Default Thickness", Range(0.1,1)) = 0.3
		_ShorelineFoamThickness("Shoreline Foam Thickness", Range(1,10)) = 0.1
		_ShorelineFoamSpeed("Shoreline Foam Speed", Range(0,1)) = 0.1

		[Header(Floating Foam)]
		_FloatingFoamPos("Floating Foam Position (Mask)", 2D) = "white"{}
		_FloatingFoamTex("Floating Foam Texture", 2D) = "white"{}
		_FloatingFoamColor("Floating Foam Color", Color) = (1,1,1,1)
		_FloatingFoamTiling("Floating Foam Tiling", Range(1,10)) = 1
		_FloatingFoamThickness("Floating Foam Thickness", Range(0.01,2)) = 0.1
		_FloatingFoamSpeed("Floating Foam Speed", Range(0.1,1)) = 0.1

		// Properties에 추가
		[Header(Caustics Settings)]
		_CausticsTex("Caustics Texture", 2D) = "black" {}
		_CausticsColor("Caustics Color", Color) = (1,1,1,1)
		_CausticsTiling("Caustics Tiling", Range(0.1, 4)) = 1
		_CausticsSpeed("Caustics Speed", Range(0, 1)) = 0.1
		_CausticsThreshold("Caustics Threshold", Range(0, 1)) = 0.5
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
				sampler2D _BumpTex; 
				sampler2D _CausticsTex;
				

				struct Input
				{
					float2 uv_BumpTex;
					float2 uv_ShorelineFoamTex;
					float2 uv_FloatingFoamPos;
					float2 uv_FloatingFoamTex;
					float2 uv_Caustics;
					float4 screenPos;
					float3 worldRefl;
					float3 worldPos;
					float3 viewDir;
					INTERNAL_DATA
				};

				half4 _WaterColor, _DeepWaterColor, _FresnelColor, _SpecularColor, _ShorelineColor, _ShorelineFoamColor, _FloatingFoamColor;
				float _FresnelPower, _FresnelOffset, _SpecularPower, _BumpSpeed;
				float _ShorelineFoamTiling, _ShorelineFoamThickness, _ShorelineDefaultThickness, _ShorelineFoamSpeed;
				float _FloatingFoamTiling, _FloatingFoamThickness, _FloatingFoamSpeed;
				float _WaveTime, _WaveFrequency, _WaveAmplitude;
				half4 _CausticsColor;
				float _CausticsTiling, _CausticsSpeed, _CausticsThreshold;

				UNITY_INSTANCING_BUFFER_START(Props)
				UNITY_INSTANCING_BUFFER_END(Props)

				void vert(inout appdata_full v)
				{
					float movement;
					movement = sin(abs(v.texcoord.x * 2 - 1) * _WaveFrequency + _Time.y * _WaveTime) * _WaveAmplitude;
					movement += sin(abs(v.texcoord.y * 2 - 1) * _WaveFrequency + _Time.y * _WaveTime) * _WaveAmplitude;
					v.vertex.y += movement*0.5;
				}

				// 다중 해안가 라인을 계산하는 함수
				half CalculateMultiShoreline(float area, float time, float speed, float count, float foam)
				{
					// 1. 시간에 따른 오프셋 (안쪽으로 밀려오는 움직임)
					float waveOffset = time * speed * 20.0 ;

					// 2. 파동 함수 (영역에 따라 반복되는 sin 파형)
					float wave = sin(area * count * UNITY_PI * 2 - waveOffset);

					// 3. 스타일라이즈드 처리를 위한 하드 엣지 (0.8 이상만 출력)
					float lines = step(0.8, wave);

					// 4. 해안가에서 멀어질수록 감쇄 (영역 제한)
					lines *= saturate(1.0 - area);

					return (half)lines;
				}

				// 스타일라이즈드 화선(Caustics) 계산 함수
				half3 CalculateCaustics(float3 worldPos, half3 causticsColor, float tiling, float speed, float threshold, float rawDepth)
				{
					// --- 0. Fake Depth 생성 ---
					// 수면(보통 0)으로부터의 거리를 계산합니다.
					// float distFromSurface = max(0, _WaveAmplitude - worldPos.y);
					float fakeDepth = saturate(rawDepth)*saturate(pow(1-rawDepth,1.0));
					//return fakeDepth;
					// --- 1. 기본 UV 및 애니메이션 설정 ---
					float2 uv = worldPos.xz * 0.01 * tiling;
					float2 move1 = float2(_Time.y, _Time.y * 0.5) * speed;
					float2 move2 = float2(_Time.y * 0.6, _Time.y * -0.3) * speed;

					half mask1 = tex2D(_CausticsTex, uv * 0.6 + move1).r;
					half mask2 = tex2D(_CausticsTex, uv * 0.4 + move2).r;

					// --- 2. 수면용 화선 (밝고 또렷하게 위에 뜨는 느낌) ---
					// threshold를 높게 잡아 얇고 날카로운 선을 만듭니다.
					half surfaceMask = step(threshold, mask1);
					// 수면 근처(fakeDepth가 낮을 때)에서만 강하게 나타나도록 설정
					half3 surfaceCaustics = surfaceMask * causticsColor.rgb; // 밝게 강조

					// --- 3. 바닥용 화선 (진하고 흐리게 깔리는 느낌) ---
					// threshold를 낮게 잡아 면적을 넓히고, 뭉툭하게 만듭니다.
					half floorMask = smoothstep(threshold - 0.2, threshold + 0.1, mask2)*0.5;
					floorMask *= fakeDepth;// smoothstep(0.4, 0.0, fakeDepth);
					// 물 색상보다 어둡거나 진한 톤으로 설정 (causticsColor의 명도를 낮춰서 사용 가능)
					half3 floorCaustics = floorMask * causticsColor.rgb ;

					// --- 4. 최종 결합 ---
					return surfaceCaustics + floorCaustics;
				}

				void surf(Input IN, inout SurfaceOutput o)
				{
					float3 normal1 = UnpackNormal(tex2D(_BumpTex, IN.uv_BumpTex + _Time.x * _BumpSpeed));
					float3 normal2 = UnpackNormal(tex2D(_BumpTex, IN.uv_BumpTex - _Time.x * _BumpSpeed));
					o.Normal = (normal1 + normal2) / 2;

					// 1. Floating Foam 연산
					float2 timeOffset = float2(_Time.y, _Time.y / 2) * _FloatingFoamSpeed;
					float4 floatingPos = tex2D(_FloatingFoamPos, IN.uv_FloatingFoamPos * _FloatingFoamTiling + timeOffset);
					float4 floatingTex = tex2D(_FloatingFoamTex, IN.uv_FloatingFoamTex * _FloatingFoamTiling + timeOffset);

					// 2. Shoreline Foam 연산
					float shorelineFoam = 1.0 - tex2D(_ShorelineFoamTex, IN.uv_ShorelineFoamTex * _ShorelineFoamTiling + float2(_Time.y, _Time.y / 2) * _ShorelineFoamSpeed).r;
					shorelineFoam = step(0.8, shorelineFoam);
					float shorelineMask = 0.0;
					float depth = LinearEyeDepth(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(IN.screenPos)).r);
					
					float rawDepth = depth - IN.screenPos.w;
					float shorelineArea = saturate(rawDepth / _ShorelineFoamThickness);
					float3 baseOcean = lerp(_WaterColor.rgb, _DeepWaterColor.rgb, pow(saturate(rawDepth/20.0), 2.0));

					shorelineMask = (shorelineArea <= _ShorelineDefaultThickness) ? 1.0 : shorelineMask; // 가장 가까운 고정된 shoreline
					// shorelineMask = shorelineMask * (1.0 - shorelineArea);  // 자연스러운 fade
					shorelineMask = shorelineMask * smoothstep(0.9, 0.4, shorelineArea); // p1 보다 작으면 0 p2보다 크면 1
					
					// --- 다중 Shoreline 라인 추가 로직 ---
					half multiLines = CalculateMultiShoreline(shorelineArea, _Time.y, _ShorelineFoamSpeed, 2.0, shorelineFoam);
					shorelineMask = saturate(shorelineMask + multiLines);

					// 3. Floating Foam Masking
					float animatedThreshold = saturate(sin(_Time.y * 0.8) * 0.5 + 0.5) * 0.4;
					float finalMask = smoothstep(animatedThreshold, animatedThreshold + 0.6, floatingPos.r);
					float3 floatingFoamResult = floatingTex.rgb * _FloatingFoamColor.rgb * (floatingPos.a * finalMask);

					// 4. 프레넬 계산 (surf 단계로 이동하여 색상 통제)
					// viewDir와 Normal의 각도 계산 (o.Normal은 기본적으로 0,1,0)
					float rim = saturate(dot(normalize(IN.viewDir), o.Normal));
					float fresnelFactor = saturate(pow(1.0 - rim, _FresnelPower) + _FresnelOffset);
					
					half3 causticsResult = CalculateCaustics(
						IN.worldPos,
						_CausticsColor,
						_CausticsTiling,
						_CausticsSpeed,
						_CausticsThreshold,
						shorelineArea
					);
					// 5. 최종 색상 혼합 (lerp를 중첩하여 버닝 방지)
					// (A) 물색과 프레넬 색 혼합
					baseOcean = lerp(baseOcean.rgb, _FresnelColor.rgb, fresnelFactor);

					// (B) 물색에 shoreline 섞음
					float3 withShoreline = baseOcean + _ShorelineColor.rgb*shorelineMask;//lerp(baseOcean, _ShorelineColor.rgb, shorelineMask);

					// (C) 마지막으로 부유 거품(Floating Foam) 더하기 혹은 섞기
					// 거품이 아주 밝아야 하므로 여기서는 Emission에 더해줍니다.
					o.Emission = withShoreline + causticsResult + saturate(1.0- shorelineArea)*0.7;// +floatingFoamResult;
					o.Alpha = 0.8; // ocean.a 고정값 적용
				}

				float4 LightingWater(SurfaceOutput s, float3 lightDir, float3 viewDir, float atten)
				{
					// 1. 하이라이트 (Specular) 계산
					// Blinn-Phong 모델을 사용하여 태양빛이 반사되는 날카로운 점을 만듭니다.
					float3 h = normalize(lightDir + viewDir);
					float nh = saturate(dot(s.Normal, h));
					// 부드러운 스펙큘러 베이스
					float specBase = pow(nh, _SpecularPower);

					// 2. [추가] Fake Specular를 위한 노이즈 간섭
					// Caustics에서 사용한 텍스처나 별도의 노이즈를 활용합니다.
					// 여기서는 s.Normal의 미세한 변화를 증폭시켜 유기적인 모양을 만듭니다.
					//float specNoise = tex2D(_CausticsTex, s.Normal.xz * 0.5 + _Time.y * _BumpSpeed).r;

					// 노이즈와 스펙큘러 베이스를 결합 (곱하기 혹은 더하기)
					float combinedSpec = specBase;// +(specNoise * specBase);

					// 3. [핵심] Step을 이용한 스타일라이즈드 하드 엣지
					// 0.5~0.8 사이의 값으로 조절하면 이미지처럼 또렷한 조각들이 생깁니다.
					float spec1 = step(0.5, combinedSpec); // 아주 밝은 알맹이
					float spec2 = smoothstep(0.3, 0.5, combinedSpec) * 0.5; // 주변의 은은한 번짐

					float3 stylizedSpec = (spec1 + spec2) * _SpecularColor.rgb;

					// 4. 최종 결과 출력
					float3 specularTerm = stylizedSpec * _SpecularColor.rgb;

					// 2. 프레넬 (Rim/Fresnel) 계산
					// 카메라가 보는 각도에 따라 외곽선 반사 강도를 결정합니다.
					//float rim = saturate(dot(viewDir, s.Normal));
					//float fresnelFactor = saturate(pow(1.0 - rim, _FresnelPower) + _FresnelOffset);

					// 3. 색상 혼합 (기존 로직의 안정화)
					// s.Emission에는 이미 (WaterColor + Foam)이 합쳐져 있습니다.
					// 외곽으로 갈수록 FresnelColor가 나타나도록 lerp를 사용합니다.
					//float3 waterWithFresnel = lerp(s.Emission, _FresnelColor.rgb, fresnelFactor);
					//float3 waterWithFresnel = lerp(float3(0, 0, 0), _FresnelColor.rgb, fresnelFactor);

					// 4. 최종 결과 출력
					float4 final;
					// (물 색상 + 스펙큘러)에 빛의 세기(atten)와 조명색(_LightColor0)을 반영합니다.
					final.rgb = specularTerm * 2.0 * _LightColor0.rgb * atten;
					final.a = s.Alpha;

					return final;
				}
				
			ENDCG
		}
		FallBack "Legacy Shaders/Transparent/Vertexlit"
}