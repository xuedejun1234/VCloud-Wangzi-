using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
[System.Serializable]
[VolumeComponentMenuForRenderPipeline("Custom/GodLight", typeof(UniversalRenderPipeline))]
public class GodLight : VolumeComponent, IPostProcessComponent
{
    
    [Tooltip("HG coefficients: numerator, denominator base, and cosine factor")]
    public Vector3Parameter mieScatteringFactor = new Vector3Parameter(
        new Vector3(0.02865f, 1.64f, 1.6f));
    [Tooltip("_TintColor")]
    public Vector3Parameter tintColor = new Vector3Parameter(Vector3.one);
    [Tooltip("_ExtinctionFactor")]
    public FloatParameter extictionFactor = new FloatParameter(0.2f);
    [Tooltip("Scattering strength multiplier")]
    public ClampedFloatParameter scatteringStrength = new ClampedFloatParameter(0.03f, 0f, 1f);
    [Tooltip("_RayMarchingStepCount")]
    public ClampedIntParameter rayMarchingStepCount = new ClampedIntParameter(32, 8, 128);
    
    
    public bool IsActive() => true;
    public bool IsTileCompatible() => false;

    public void load(Material material, ref RenderingData data)
    {
        material.SetVector("_MieScatteringFactor", mieScatteringFactor.value);
        material.SetVector("_TintColor", tintColor.value);
        material.SetFloat("_ExtinctionFactor", extictionFactor.value);
        material.SetFloat("_ScatteringStrength", scatteringStrength.value);
        material.SetFloat("_RayMarchingStepCount", rayMarchingStepCount.value);

    }
}
