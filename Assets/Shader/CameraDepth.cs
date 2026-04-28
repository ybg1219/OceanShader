using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode] // 에디터 모드에서도 바로 확인 가능하게 함
public class CameraDepth : MonoBehaviour
{
    public Material m_Caustics;
    private Camera cam;

    void OnEnable()
    {
        cam = GetComponent<Camera>();
        // 카메라가 뎁스 텍스처를 생성하도록 설정
        if (cam != null)
        {
            cam.depthTextureMode = DepthTextureMode.Depth;
        }
    }

    void Update()
    {
        // 1. 태양(광원) 행렬 전달
        if (RenderSettings.sun != null && m_Caustics != null)
        {
            // worldToLocalMatrix: 월드 좌표를 태양 기준 좌표로 변환
            Matrix4x4 sunMatrix = RenderSettings.sun.transform.worldToLocalMatrix;
            m_Caustics.SetMatrix("_MainLightDirection", sunMatrix);
        }
    }

    // OnPreRender는 카메라 컴포넌트가 있는 오브젝트에서만 작동합니다.
    void OnPreRender()
    {
        if (cam == null) return;

        // 2. View-Projection 역행렬 계산 및 전달
        Matrix4x4 v = cam.worldToCameraMatrix;
        Matrix4x4 p = GL.GetGPUProjectionMatrix(cam.projectionMatrix, false);
        Matrix4x4 vp = p * v;
        Matrix4x4 invVP = vp.inverse;

        // 셰이더 전역 변수로 전달 (모든 셰이더의 unity_MatrixInvVP 채우기)
        Shader.SetGlobalMatrix("unity_MatrixInvVP", invVP);
    }
}