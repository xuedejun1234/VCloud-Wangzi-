using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class VolumetricCloudFeature : ScriptableRendererFeature
{
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent evt = RenderPassEvent.BeforeRenderingPostProcessing;
    private Material matInstance;
    private VolumetricCloudPass volumetricCloudPass;

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (shader == null) return;
        if (matInstance == null || matInstance.shader != shader)
        {
            CoreUtils.Destroy(matInstance);
            matInstance = CoreUtils.CreateEngineMaterial(shader);
        }
        RenderTargetIdentifier currentRT = renderer.cameraColorTarget;
        volumetricCloudPass.Setup(currentRT, matInstance);
        renderer.EnqueuePass(volumetricCloudPass);
    }

    public override void Create()
    {
        volumetricCloudPass = new VolumetricCloudPass();
        volumetricCloudPass.renderPassEvent = evt;
    }
}