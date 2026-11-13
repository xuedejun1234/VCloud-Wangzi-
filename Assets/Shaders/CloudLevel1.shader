Shader "CloudLevel1"{
    
    Properties{
        // 着色器输入
        _MainTex("Main Texture", 2D) = "white"{}
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        
        _DensityNoiseTex("DensityNoiseTex", 3D) = "black"{}
        _DensityNoiseScale("DensityNoise_Scale", Vector) = (1, 1, 1, 1)
        _DensityNoiseOffset("DensityNoise_Offset", Vector) = (0, 0, 0, 0)
        
        _DensityErode_Scale("DensityErode_Scale", Vector) = (1, 1, 1, 1)
        _DensityErode_Offset("DensityErode_Offset", Vector) = (0, 0, 0, 0)
        _DensityErodeTex("DensityErodeTex", 3D) = "white"{}
        _DensityErode("DensityErode", Float) = 1
        
        _EdgeSoftnessThreshold("EdgeSoftnessThreshold", Vector) = (1, 1, 1, 1)
        
        _Absorption("Absorption", Float) = 1
        _LightAbsorption ("LightAbsorption ", Float) = 1
        _LightPower("LightPower", Float) = 1
        _Sigma("Sigma", Vector) = (0.5,1,2)
        _HgPhaseG0("HgPhaseG0", Range(-0.99, 0.99)) = 0
        _HgPhaseG1("HgPhaseG1", Range(-0.99, 0.99)) = 0
        
        _HeightMin("_HeightMin", Float) = 300
        _HeightMax("_HeightMax", Float) = 600
        _Radius("Radius", Float) = 6300000
        _Center("Center", Vector) = (0, 0, 0, 0)
    }
    SubShader{
        Tags{
            "RenderPipeline" = "UniversalRenderPipeline"
        }
        pass{

            Cull Off
            ZTest Always
            ZWrite Off
            
            HLSLPROGRAM
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

                #pragma vertex Vertex
                #pragma fragment Pixel

                Texture2D _MainTex;
                SamplerState sampler_MainTex;
                half4 _BaseColor;
                
                sampler3D _DensityNoiseTex;
                float3 _DensityNoiseScale;
                float3 _DensityNoiseOffset;
                float _DensityScale;
                
                float3 _DensityErode_Scale;
                float3 _DensityErode_Offset;
                sampler3D _DensityErodeTex;
                float _DensityErode;
                
                
                float _Absorption;
                float _LightAbsorption;
                float _LightPower;
                
                float3 _Sigma;
                float _HgPhaseG0 = 0.8;
                float _HgPhaseG1 = -0.5;
                

                
                float3 _Center;
                float _Radius;
                float _HeightMin;
                float _HeightMax;
                
                float3 _EdgeSoftnessThreshold;
                
                struct vertexInput{
                    float4 vertex: POSITION;
                    float2 uv: TEXCOORD0;
                };
                struct vertexOutput{
                    float4 pos: SV_POSITION;
                    float2 uv: TEXCOORD0;
                };
                //获取某个屏幕像素对应的场景世界坐标。
                float3 GetWorldPosition(float3 positionHCS){
                    /* get world space position from clip position */

                    float2 UV = positionHCS.xy / _ScaledScreenParams.xy;
                    #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(UV);
                    #else
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                    #endif
                    return ComputeWorldSpacePosition(UV, depth, UNITY_MATRIX_I_VP);
                }
                
                //射线与球体相交, x 到球体最近的距离， y 穿过球体的距离
                //原理是将射线方程(x = o + dl)带入球面方程求解(|x - c|^2 = r^2)
                float2 RaySphereDst(float3 sphereCenter, float sphereRadius, float3 pos, float3 rayDir)
                {
                    float3 oc = pos - sphereCenter;
                    float b = dot(rayDir, oc);
                    float c = dot(oc, oc) - sphereRadius * sphereRadius;
                    float t = b * b - c;//t > 0有两个交点, = 0 相切， < 0 不相交
                    
                    float delta = sqrt(max(t, 0));
                    float dstToSphere = max(-b - delta, 0);
                    float dstInSphere = max(-b + delta - dstToSphere, 0);
                    return float2(dstToSphere, dstInSphere);
                }
                

                //浓度（云密度）采样
                float sampleDensity(float3 position){

                    float3 uvw = position * _DensityNoiseScale * 0.01 + _DensityNoiseOffset * _Time.y *0.01;
                    
                    float density = tex3D(_DensityNoiseTex, uvw).r;

                    float3 erodeUVW = position * _DensityErode_Scale * 0.01 + _DensityErode_Offset * _Time.y *0.01;
                    float erode = tex3D(_DensityErodeTex, erodeUVW).r * _DensityErode;

                    // float edgeToX = min(_EdgeSoftnessThreshold.x, min(position.x - _BoundsMin.x, _BoundsMax.x - position.x));
                    // float edgeToZ = min(_EdgeSoftnessThreshold.z, min(position.z - _BoundsMin.z, _BoundsMax.z - position.z));
                    // float edgeToY = min(_EdgeSoftnessThreshold.y, min(position.y - _BoundsMin.y, _BoundsMax.y - position.y));
                    // float softness = edgeToX/ _EdgeSoftnessThreshold.x * edgeToZ / _EdgeSoftnessThreshold.x * edgeToY / _EdgeSoftnessThreshold.y;

                    density = max(0, density - erode) * _DensityScale;
                                        return density;
                }
                
                
                
                float SchlickPhaseFunction(float a, float g)
                {
                    /* 施利克相位函数，对亨利·格林斯坦函数做近似 */
                    float k = 1.55 *g - 0.55 * g * g * g;
                    return (1.0 - k * k) / (12.56637 * pow(1 - k * a, 2));
                }


                float HgPhaseFunction(float a, float g){
                    /* 亨利·格林斯坦相位函数，也就是HG相位函数 
                       r(a, g) = (1 - g^2)/(4pi * ( 1 + g^2 - 2ga )^1.5 )
                       其中a是入射光和视角方向的夹角，g是描述体积云（雾）的性质的常量参数, g为0时。
                       云向四面八方进行散射，所有方向散射结果一致，呈现各向同性。*/

                    float g2 = g * g;
                    return (1 - g2)/(12.56637 * pow(1 + g2 - 2 * g * a, 1.5));
                }
                
                float3 BeerPowder(float3 d, float a)
                {
                    return exp(-d * a) * (1 - exp(-d* 2 * a));
                }
                
                //射线与云层相交, x到云层的最近距离, y穿过云层的距离
                //通过两个射线与球体相交进行计算
                float2 RayCloudLayerDst(float3 sphereCenter, float earthRadius, float heightMin, float heightMax, float3 pos, float3 rayDir, bool isShape = true)
                {
                    float2 cloudDstMin = RaySphereDst(sphereCenter, heightMin + earthRadius, pos, rayDir);
                    float2 cloudDstMax = RaySphereDst(sphereCenter, heightMax + earthRadius, pos, rayDir);
                    
                    //射线到云层的最近距离
                    float dstToCloudLayer = 0;
                    //射线穿过云层的距离
                    float dstInCloudLayer = 0;
                    
                    //形状步进时计算相交
                    if (isShape)
                    {
                        
                        //在地表上
                        if (pos.y <= heightMin)
                        {
                            float3 startPos = pos + rayDir * cloudDstMin.y;
                            //开始位置在地平线以上时，设置距离
                            if (startPos.y >= 0)
                            {
                                dstToCloudLayer = cloudDstMin.y;
                                dstInCloudLayer = cloudDstMax.y - cloudDstMin.y;
                            }
                            return float2(dstToCloudLayer, dstInCloudLayer);
                        }
                        
                        //在云层内
                        if (pos.y > heightMin && pos.y <= heightMax)
                        {
                            dstToCloudLayer = 0;
                            dstInCloudLayer = cloudDstMin.y > 0 ? cloudDstMin.x: cloudDstMax.y;
                            return float2(dstToCloudLayer, dstInCloudLayer);
                        }
                        
                        //在云层外
                        dstToCloudLayer = cloudDstMax.x;
                        dstInCloudLayer = cloudDstMin.y > 0 ? cloudDstMin.x - dstToCloudLayer: cloudDstMax.y;
                    }
                    else//光照步进时，步进开始点一定在云层内
                    {
                        dstToCloudLayer = 0;
                        dstInCloudLayer = cloudDstMin.y > 0 ? cloudDstMin.x: cloudDstMax.y;
                    }
                    
                    return float2(dstToCloudLayer, dstInCloudLayer);
                }
                
                float LightPathDensity(float3 position, int stepCount, float3 sphereCenter){
                    /* sample density from given point to light 
                       within target step count */

                    // URP的主光源位置的定义名字换了一下
                    float3 dirToLight = _MainLightPosition.xyz;

                    /* 这里的给传入的方向反向了一下是因为，rayBoxDst的计算是要从
                       目标点到体积，而采样时，则是反过来，从position出发到主光源*/
                    float dstInsideBox = RayCloudLayerDst(sphereCenter, _Radius, _HeightMin, _HeightMax, position, dirToLight).y;

                    // 采样
                    float stepSize = dstInsideBox / stepCount;
                    float totalDensity = 0;
                    float3 stepVec = dirToLight * stepSize;
                    for(int i = 0; i < stepCount; i ++){
                        position += stepVec;
                        totalDensity += max(0, sampleDensity(position) * stepSize);
                    }
                    return totalDensity;
                }
                
                vertexOutput Vertex(vertexInput v){

                    vertexOutput o;
                    o.pos = TransformObjectToHClip(v.vertex);
                    o.uv = v.uv;
                    return o;
                }
                
                
                half4 Pixel(vertexOutput IN): SV_TARGET{
                    
                    // 采样主纹理
                    half4 albedo = _MainTex.Sample(sampler_MainTex, IN.uv);

                    // 重建世界坐标
                    float3 worldPosition = GetWorldPosition(IN.pos);
                    float3 rayPosition = _WorldSpaceCameraPos.xyz;
                    float3 worldViewVector = worldPosition - rayPosition;
                    float3 rayDir = normalize(worldViewVector);
                    float3 sphereCenter = float3(rayPosition.x, -_Radius, rayPosition.z);
                    // 碰撞体积计算
                    float2 rayBoxInfo = RayCloudLayerDst(sphereCenter, _Radius, _HeightMin, _HeightMax,rayPosition, rayDir);
                    float dstToBox = rayBoxInfo.x;
                    float dstInsideBox = rayBoxInfo.y;
                    float dstToOpaque = length(worldViewVector);
                    float dstLimit = min(dstToOpaque - dstToBox, dstInsideBox);

                    // 浓度采样
                    int stepCount = 32;                                         // 采样的次数
                    float stepSize = dstInsideBox / stepCount;                  // 步进的长度
                    float3 stepVec = rayDir * stepSize;                         // 步进向量
                    float3 currentPoint = rayPosition + dstToBox * rayDir;      // 采样起点
                    float totalDensity = 0;
                    float dstTravelled = 0;
                    float3 lightIntensity = 0.0;
                    float transmittance = 1.0;
                    
                    float _costheta = dot(rayDir, _MainLightPosition.xyz);
                    float phaseVal = lerp(
                        HgPhaseFunction(_costheta, _HgPhaseG0), 
                        HgPhaseFunction(_costheta, _HgPhaseG1), 
                        0.5
                    );
                    
                    for(int i = 0; i < stepCount; i ++){
                        if(dstTravelled < dstLimit){
                            float Dx = sampleDensity(currentPoint) * stepSize;
                            totalDensity += Dx;
                            /* 从主光源接受到的能量首先会被云层的吸收，于是乘以exp(-Dx * _LightAbsorption * _Sigma)
                             * 以及该点的云的浓度越高，越能接受足够的能量，于是乘以Dx
                             * 再乘以相位函数结果phaseVal赋予其针对观察视角的亮度差异 */
                            const float density_to_light = LightPathDensity(currentPoint, 8 , sphereCenter);
                            float3 energy = BeerPowder(density_to_light * _LightAbsorption * _Sigma, 6) * Dx * _Sigma * phaseVal;

                            /* 进行多次散射模拟，具体看下面的链接
                             * https://www.ea.com/frostbite/news/physically-based-sky-atmosphere-and-cloud-rendering */
                            const float sigma = _LightAbsorption * _Sigma;
                            energy = (energy - energy * BeerPowder(density_to_light * sigma, 6)) / sigma;
                            
                            lightIntensity += energy * transmittance;
                            transmittance *= exp(-Dx * _Absorption);
                            
                            currentPoint += stepVec;
                            dstTravelled += stepSize;
                            continue;
                        }
                        break;
                    }
                    
                    
                    float3 cloudColor = _MainLightColor.xyz * lightIntensity * _BaseColor.xyz * _LightPower;
                    // return  float4(_Sigma * 0.25, 1);
                    return half4(albedo * transmittance + cloudColor, 1);
                }
                
                
            ENDHLSL
        }
    }
}