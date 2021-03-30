using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class Atmosphere : MonoBehaviour
{
    public Material _mat;

    public float RedLightWave = 700.0f;
    public float GreenLightWave = 525.0f;
    public float BlueLightWave = 440.0f;
    public float ScatteringStrength = 1.0f;

    void Start()
    {
        GetComponent<Camera>().depthTextureMode = DepthTextureMode.Depth;
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Vector3 scatteringCoeff =
            new Vector3(
                Mathf.Pow(400 / RedLightWave, 4) * ScatteringStrength,
                Mathf.Pow(400 / GreenLightWave, 4) * ScatteringStrength,
                Mathf.Pow(400 / BlueLightWave, 4) * ScatteringStrength);
        _mat.SetVector("_ScatteringCoeff", scatteringCoeff);
        Graphics.Blit(source, destination, _mat);
    }
}
