using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[System.Serializable]
[VolumeComponentMenuForRenderPipeline("Custom/VolumetricCloud", typeof(UniversalRenderPipeline))]
public class VolumetricCloud: VolumeComponent, IPostProcessComponent{
    [Header("Shape Controller")]
    [Tooltip("Density Noise")]
    public Texture3DParameter densityNoise = new Texture3DParameter(null);
    [Tooltip("DensityErodeTex")]
    public Texture3DParameter densityErodeTex = new Texture3DParameter(null);
    [Tooltip("Density Noise Scale")]
    public Vector3Parameter densityNoiseScale = new Vector3Parameter(Vector3.one);
    [Tooltip("Density Noise Offset")]
    public Vector3Parameter densityNoiseOffset = new Vector3Parameter(Vector3.zero);
    
    [Tooltip("DensityErode_Scale")]
    public Vector3Parameter densityErode_Scale = new Vector3Parameter(Vector3.one);
    [Tooltip("DensityErode_Offset")]
    public Vector3Parameter densityErode_Offset = new Vector3Parameter(Vector3.zero);
    [Tooltip("DensityScale")]
    public FloatParameter densityScale = new FloatParameter(1f);
    [Tooltip("_DensityErode")]
    public FloatParameter densityErode = new FloatParameter(1f);
    
    [Tooltip("Center")]
    public Vector3Parameter center = new Vector3Parameter(Vector3.one);
    [Tooltip("Radius")]
    public FloatParameter radius = new FloatParameter(1f);
    [Tooltip("HeightMin")]
    public FloatParameter heightMin = new FloatParameter(1f);
    [Tooltip("HeightMax")]
    public FloatParameter heightMax = new FloatParameter(1f);
    
    
    
    [Header("Lighting Controller")]
    [Tooltip("Base Color")]
    public ColorParameter baseColor = new ColorParameter(new Color(1, 1, 1, 1));
    [Tooltip("Absorption")]
    public FloatParameter absorption = new FloatParameter(1f);
    [Tooltip("LightAbsorption")]
    public FloatParameter lightAbsorption = new FloatParameter(1f);
    [Tooltip("LightPower")]
    public FloatParameter lightPower = new FloatParameter(1f);
    [Tooltip("Sigma")]
    public Vector3Parameter sigma = new Vector3Parameter(Vector3.one);
    
    [Tooltip("HgPhaseG0")]
    public ClampedFloatParameter hgPhaseG0 = new ClampedFloatParameter(0f,-0.99f, 0.99f);
    [Tooltip("HgPhaseG1")]
    public ClampedFloatParameter hgPhaseG1 = new ClampedFloatParameter(0f,-0.99f, 0.99f);
    
    
    
    
    public bool IsActive() => true;
    public bool IsTileCompatible() => false;
    public void load(Material material, ref RenderingData data){
        /* 将所有的参数载入目标材质 */

        material.SetColor("_BaseColor", baseColor.value);
        if(densityNoise != null){
            material.SetTexture("_DensityNoiseTex", densityNoise.value);
        }
        
        if(densityErodeTex != null){
            material.SetTexture("_DensityErodeTex", densityErodeTex.value);
        }
        
        material.SetVector("_DensityNoiseScale", densityNoiseScale.value );
        material.SetVector("_DensityNoiseOffset", densityNoiseOffset.value);
        
        material.SetVector("_DensityErode_Scale", densityErode_Scale.value);
        material.SetVector("_DensityErode_Offset", densityErode_Offset.value);
        
        material.SetFloat("_Absorption", absorption.value);
        material.SetFloat("_LightAbsorption", lightAbsorption.value);
        material.SetFloat("_LightPower", lightPower.value);
        material.SetVector("_Sigma", sigma.value);
        material.SetFloat("_HgPhaseG0", hgPhaseG0.value);
        material.SetFloat("_HgPhaseG1", hgPhaseG1.value);
        material.SetFloat("_DensityScale", densityScale.value);
        material.SetFloat("_DensityErode", densityErode.value);
        material.SetVector("_Center", center.value);
        material.SetFloat("_Radius", radius.value);
        material.SetFloat("_HeightMin", heightMin.value);
        material.SetFloat("_HeightMax", heightMax.value);
    }
}
