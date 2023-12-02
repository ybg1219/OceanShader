Shader "Custom/SS_Blending"
{
    Properties
    {
        _MainTint("Main Tint", Color) = (1,1,1,1)
        _ColorA ("ColorA", Color) = (1,1,1,1)
        _ColorB("ColorB", Color) = (1,1,1,1)
        _BlendTex("Blend Texture", 2D) = "white" {}
        _RTex("R channel", 2D) = "white" {}
        _GTex("G channel", 2D) = "white" {}
        _BTex("B channel", 2D) = "white" {}
        _ATex("A channel", 2D) = "white" {}
    }
        SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.5 // texture 개수 때문에 3.5이상으로 변경.
        float4 _MainTint;
        float4 _ColorA;
        float4 _ColorB;
        sampler2D _BlendTex;
        sampler2D _RTex;
        sampler2D _GTex;
        sampler2D _BTex;
        sampler2D _ATex;


        struct Input
        {
            float2 uv_BlendTex;
            float2 uv_RTex;
            float2 uv_GTex;
            float2 uv_BTex;
            float2 uv_ATex;

        };

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float4 blendData = tex2D(_BlendTex, IN.uv_BlendTex);
            float4 RData = tex2D(_RTex, IN.uv_RTex);
            float4 GData = tex2D(_GTex, IN.uv_GTex);
            float4 BData = tex2D(_BTex, IN.uv_GTex);
            float4 AData = tex2D(_ATex, IN.uv_ATex);

            float4 finalColor = lerp(RData, GData, blendData.g); // r,g 혼합 1일 때 두번째 인수값 들어가는 거니까 G
            finalColor = lerp(finalColor,BData,blendData.b); //b혼합
            finalColor = lerp(finalColor, AData, blendData.a); //a값 혼합
            finalColor.a = 1.0;

            float4 terrainLayers = lerp(_ColorA,_ColorB,blendData.r);
            finalColor *= terrainLayers;
            finalColor = saturate(finalColor);
            o.Albedo = finalColor.rgb * _MainTint.rgb;
            o.Alpha = finalColor.a;

        }
        ENDCG
    }
    FallBack "Diffuse"
}
