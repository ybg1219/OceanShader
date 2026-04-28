Shader "Unlit/UL_Caustics"
{
	Properties
	{
		_MainTex("Caustics Texture", 2D) = "white" {}
		_SplitStrength("Chromatic Aberration Strength", Range(0, 0.1)) = 0.02

		_CausticsSpeed("Caustic Speed", Range(0, 0.5)) = 0.2
		_CausticsScale("Caustic Scale", Range(0.1, 20.0)) = 1.0

		_CausticsFadeRadius("Fade Radius", Range(0, 1)) = 0.4
		_CausticsFadeStrength("Fade Strength", Range(0, 1)) = 0.2
	}
		SubShader
		{
			// 배경 위에 덧그려야 하므로 Transparent 큐와 Additive 블렌딩 사용
			Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
			LOD 100

			Cull Front     // 박스의 안쪽(뒷면)을 렌더링 (카메라가 박스 내부에 있을 때 대응)
			ZTest Always
			ZWrite Off
			Blend One One // Additive 블렌딩: 빛이 겹치듯 밝아짐

			Pass
			{
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#include "UnityCG.cginc"

				float4x4 unity_MatrixInvVP;
				
				struct appdata
				{
					float4 vertex : POSITION;
				};

				struct v2f
				{
					float4 pos : SV_POSITION;
					float4 screenPos : TEXCOORD0; // 화면 좌표 전달
					float3 viewRay : TEXCOORD1; // 카메라에서 박스 정점까지의 방향
				};

				sampler2D _MainTex;
				float4 _MainTex_ST;
				sampler2D _CameraDepthTexture; // 유니티가 제공하는 뎁스 텍스처
				float _SplitStrength;
				float4x4 _MainLightDirection;
				float _CausticsSpeed, _CausticsScale;
				float _CausticsFadeRadius, _CausticsFadeStrength;

				fixed3 SampleCaustics(float2 uv, float _SplitStrength) {
					// R, G, B 채널별로 미세한 오프셋을 주어 무지개 효과 생성
					fixed r = tex2D(_MainTex, uv + _SplitStrength).r;
					fixed g = tex2D(_MainTex, uv).g;
					fixed b = tex2D(_MainTex, uv - _SplitStrength).b;

					return fixed3(r, g, b);
				}

				v2f vert(appdata v)
				{
					v2f o;
					o.pos = UnityObjectToClipPos(v.vertex);
					// 화면상의 좌표(스크린 좌표) 계산
					o.screenPos = ComputeScreenPos(o.pos);

					// 카메라 좌표계에서의 정점 위치를 구해서 방향(Ray)을 계산합니다.
					float3 viewPos = UnityObjectToViewPos(v.vertex); // 의미
					o.viewRay = viewPos;// *(-1.0 / viewPos.z);

					return o;
				}


				fixed4 frag(v2f i) : SV_Target
				{
					// 1. 화면 좌표 정규화 (0~1 범위)
					float2 uv = i.screenPos.xy / i.screenPos.w;
					
					// 2. 뎁스 버퍼에서 깊이 값 읽기
					float dist = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
					float linear01 = Linear01Depth(dist);
					float4 clipPos = float4(uv * 2.0 - 1.0, 1.0, 1.0);

					#if UNITY_REVERSED_Z
						// DirectX 환경: 뎁스 값이 그대로 Z가 됨
						clipPos.z = dist;
						//if (dist < 0.0001) return float4(1, 0, 0, 1);
						//if (dist < 0.9999) return float4(0, 0, 1, 1);
					#else
						// OpenGL 환경: 0~1을 -1~1 범위로 변환 필요
						clipPos.z = dist * 2.0 - 1.0;
					#endif

					// 4. [핵심] 월드 좌표 재구성 (World Position Reconstruction)
					// 카메라 위치 + (방향 * 실제거리) = 실제 해당 픽셀의 월드 좌표
					float4 viewPos = mul(unity_MatrixInvVP, clipPos); //UNITY_MATRIX_I_VP 의미
					float3 positionWS = viewPos.xyz / viewPos.w;
					// 4-2. 월드 좌표를 박스의 오브젝트 좌표로 변환
					// unity_WorldToObject 행렬을 사용하여 positionWS를 박스 기준 좌표로 바꿉니다.
					float4 positionOS = mul(unity_WorldToObject, float4(positionWS, 1.0));
					// return float4(positionOS, 1);

					float3 objectPos = positionOS.xyz / positionOS.w;

					// 4-3. 박스 범위 체크 (-0.5 ~ 0.5 사이인지)
					// 유니티 기본 큐브는 크기가 1이므로, 중심(0) 기준 -0.5 ~ 0.5가 박스 내부입니다.
					// step(a, b)는 b >= a 이면 1, 아니면 0을 반환합니다.
					float3 edge0 = step(-0.5, objectPos);
					float3 edge1 = step(objectPos, 0.5);

					// x, y, z 모든 축이 범위 안에 들어와야 하므로 다 곱한 뒤 all()을 씁니다.
					float boundingBoxMask = all(edge0 * edge1);
					
					//4-4. edge fade mask
					// objectPos는 박스 중심이 0이므로 distance(objectPos, 0)은 중심으로부터의 거리입니다.
					float d = distance(objectPos, float3(0, 0, 0));
					float edgeFadeMask = 1.0 - saturate((d - _CausticsFadeRadius) / (1.0 - _CausticsFadeStrength));

					// 5-1. 광원 기준 기본 UV 생성
					float2 lightUV = mul(_MainLightDirection, float4(positionWS, 1.0)).xy;
					float tiling = 1.0 / _CausticsScale;
					// 5-2. 두 개의 서로 다른 움직이는 UV 생성
					// UV1: 정방향으로 흐름
					float2 movingUV1 = (lightUV * tiling) + (float2(1, 1) * _Time.y * _CausticsSpeed);
					// UV2: 반대 방향으로 약간 다른 속도와 크기로 흐름 (교차 효과)
					float2 movingUV2 = (lightUV * tiling * 0.9) + (float2(-1, 0.5) * _Time.y * _CausticsSpeed * 0.7);

					// 5-3. 각각 샘플링
					fixed3 tex1 = SampleCaustics(movingUV1, _SplitStrength);
					fixed3 tex2 = SampleCaustics(movingUV2, _SplitStrength);

					// 5-4. 두 화선 결합 (min 혹은 multiply를 주로 사용합니다)
					// min을 쓰면 두 무늬가 겹치는 밝은 부분 위주로 나타나 더 선명해집니다.
					fixed3 combinedCaustics = min(tex1, tex2);

					// 6. 최종 출력
					fixed4 finalColor = fixed4(combinedCaustics, 1.0);
					return finalColor * boundingBoxMask * edgeFadeMask;
				}
				ENDCG
			}
		}
}