Shader "Custom/S_Ocean"
{
    Properties
    {
        _BumpTex ("BumpMap", 2D) = "bump" {}
        _Cube("Skybox Material",Cube) = "" {}

        _WaterColor("water color",Color) = (1,1,1,1)
        _fresnel("fresnel",Range(1,50)) = 10
        _fOffset("fresnel offset",Range(0,1)) = 0.3

        _SPColor("Specular Color", Color) = (1,1,1,1)
        _SPPower("Specular Power", Range(50,300)) = 1
        _SPMulti("Specular Multiply", Range(1,10)) = 1.0
        _Speed("Speed",Range(0,1)) = 0.2
        
        _Amplitude("Amplitude", Range(1,30)) = 1.0
        _Frequency("Frequency", Range(1,10)) = 1.0
        _WaveTime("Wave Time", Range(1,10)) = 1.0

        _FoamTex("foam Texture",2D) = "white"{}
        _FoamColor("foam Color", Color) = (1,1,1,1)
        _FoamTiling("foam Tiling", Range(1,10)) = 1
        _FoamThickness("Foam Thickness",Range(0.01,2)) = 0.1
            _FoamSpeed("Foam Speed",Range(0,1)) = 0.1


        _Refraction("Refraction Strength", Range(0,0.2)) = 0.2
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent"}
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Water alpha:blend vertex:vert

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _BumpTex;
        sampler2D _FoamTex;
        samplerCUBE _Cube;
        //sampler2D_float _CameraDepthTexture;
        sampler2D _CameraDepthTexture;

        struct Input
        {
            float2 uv_BumpTex;
            float2 uv_FoamTex;
            float4 screenPos;
            float3 worldRefl;
            INTERNAL_DATA
        };
        float4 _WaterColor;
        float _fresnel;
        float _fOffset;

        float4 _SPColor;
        float _SPPower;
        float _SPMulti;

        float _Speed;
        float4 _FoamColor;
        float _FoamTiling;
        float _FoamThickness;
        float _FoamSpeed;


        float _WaveTime;
        float _Frequency;
        float _Amplitude;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void vert(inout appdata_full v) 
        {
            float movement;
            movement = sin(abs(v.texcoord.x*2-1)*_Frequency+_Time.y)*_Amplitude;
            movement += sin(abs(v.texcoord.y*2-1)*_Frequency+_Time.y)*_Amplitude;
            v.vertex.y += movement / 2;
        }

        void surf (Input IN, inout SurfaceOutput o)
        {
            float3 normal1 = UnpackNormal(tex2D(_BumpTex, IN.uv_BumpTex+ _Time.x * _Speed));
            float3 normal2 = UnpackNormal(tex2D(_BumpTex, IN.uv_BumpTex- _Time.x * _Speed));
            o.Normal = (normal1 + normal2) / 2;
            float4 re = texCUBE(_Cube, WorldReflectionVector(IN, o.Normal));

            float f = tex2D(_FoamTex, IN.uv_FoamTex * _FoamTiling + float2(_Time.y, _Time.y / 2) * 0.1);

            //float depth = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, IN.screenPos.xy)));
            //float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, IN.screenPos.xy)).r;
            float depth = LinearEyeDepth(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(IN.screenPos)).r); // /IN.screenPos.w 하면 원근 투영인 
            float depthDef = saturate((depth - IN.screenPos.w)*_FoamThickness);
            float3 foam = saturate(re.rgb+_FoamColor.rgb*f);
            o.Emission = lerp(foam, re.rgb , depthDef); 
        }
        float4 LightingWater(SurfaceOutput s, float3 lightDir, float3 viewDir, float atten) {
            //specular
            float3 h = normalize(lightDir + viewDir);
            float spec = saturate(dot(s.Normal, h));
            spec = pow(spec, _SPPower);
           
            //rim
            float rim = saturate(dot(viewDir, s.Normal));
            rim = saturate(pow(1-rim, _fresnel)); //fOffset 물이 너무 투명한 것 방지.

            float4 final;
            final.rgb = spec * _SPColor.rgb * _SPMulti;
            final.a = rim +spec;
            return final;
        }

        ENDCG
    }
    FallBack "Legacy Shaders/Transparent/Vertexlit"
}
