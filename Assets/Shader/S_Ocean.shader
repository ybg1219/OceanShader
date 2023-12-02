Shader "Custom/S_Ocean"
{
    Properties
    {
        _BumpTex ("BumpMap", 2D) = "bump" {}
        _Cube("Skybox Material",Cube) = "" {}

        _fresnel("fresnel",Range(1,10)) = 3

        _SPColor("Specular Color", Color) = (1,1,1,1)
        _SPAmplitude ("Specular Amplitude", Range(20,200)) = 0.5
        _SPMulti ("Specular Multiply", Range(1,10)) = 1.0
        
        _WaveHeight("Wave Height", Range(1,10)) = 1.0
        _WaveLength("Wave Length", Range(1,10)) = 1.0
        _WaveTime("Wave Time", Range(1,10)) = 1.0

        _Refraction("Refraction Strength", Range(0,0.2)) = 0.2
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent"}
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Water alpha:blend

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _BumpTex;
        samplerCUBE _Cube;

        struct Input
        {
            float2 uv_BumpTex;
            float3 worldRefl;
            INTERNAL_DATA
        };
        float _fresnel;
        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutput o)
        {
            o.Normal = UnpackNormal(tex2D(_BumpTex, IN.uv_BumpTex));
            float4 re = texCUBE(_Cube, WorldReflectionVector(IN, o.Normal));

            o.Albedo = 0;
            o.Alpha += 0.5;
            o.Emission = re.rgb;
        }
        float4 LightingWater(SurfaceOutput s, float3 lightDir, float3 viewDir, float atten) {
            float rim = saturate(dot(viewDir, s.Normal));
            rim = pow(1-rim, _fresnel);

            float4 final = rim;
            return final;
        }

        ENDCG
    }
    FallBack "Diffuse"
}
