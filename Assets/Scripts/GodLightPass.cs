using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GodLightPass : ScriptableRenderPass
{
    private const string PassTag = "God Light Ray Marching";
    private Material mat;
    private RenderTargetIdentifier sourceRT;
    private RenderTargetHandle tempRT;

    public GodLightPass()
    {
        tempRT.Init("_GodLightTempRT");
        ConfigureInput(ScriptableRenderPassInput.Depth);
    }

    public void Setup(Material material)
    {
        mat = material;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        sourceRT = renderingData.cameraData.renderer.cameraColorTarget;

        RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
        descriptor.depthBufferBits = 0;
        descriptor.msaaSamples = 1;
        cmd.GetTemporaryRT(tempRT.id, descriptor, FilterMode.Bilinear);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (mat == null)
            return;

        GodLight godLight = VolumeManager.instance.stack.GetComponent<GodLight>();
        if (godLight == null || !godLight.IsActive())
            return;

        godLight.load(mat, ref renderingData);

        CommandBuffer cmd = CommandBufferPool.Get(PassTag);
        cmd.Blit(sourceRT, tempRT.Identifier(), mat, 0);
        cmd.Blit(tempRT.Identifier(), sourceRT);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        cmd.ReleaseTemporaryRT(tempRT.id);
    }
}
