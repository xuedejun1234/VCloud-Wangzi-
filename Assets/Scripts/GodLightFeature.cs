using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace DefaultNamespace
{
    public class GodLightFeature : ScriptableRendererFeature
    {
        [SerializeField] private Shader shader;
        [SerializeField] private RenderPassEvent evt = RenderPassEvent.BeforeRenderingPostProcessing;
        private Material matInstance;
        private GodLightPass godLightPass;


        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if(shader == null) return;


            if (matInstance == null || matInstance.shader != shader)
            {
                CoreUtils.Destroy(matInstance);
                matInstance = CoreUtils.CreateEngineMaterial(shader);
            }

            godLightPass.Setup(matInstance);
            renderer.EnqueuePass(godLightPass);
        }

        public override void Create()
        {
            godLightPass = new GodLightPass();
            godLightPass.renderPassEvent = evt;
        }

        protected override void Dispose(bool disposing)
        {
            CoreUtils.Destroy(matInstance);
            matInstance = null;
        }
    }
}
