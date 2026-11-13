Shader "RedSaw/VolumetricCloud"{
    
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
        
        _BoundsMax("_BoundsMax", Vector) = (1, 1, 1)
        _BoundsMin("_BoundsMin", Vector) = (0, 0, 0)
        
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
                
                float3 _BoundsMax;
                float3 _BoundsMin;
                
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
                
                float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 rayDir){
                    /*  通过boundsMin和boundsMax锚定一个长方体包围盒
                        从rayOrigin朝rayDir发射一条射线，计算从rayOrigin到包围盒表面的距离，以及射线在包围盒内部的距离
                        关于更多该算法可以参考：https://jcgt.org/published/0007/03/04/ 
	                */

                    float3 t0 = (boundsMin - rayOrigin) / rayDir;
                    float3 t1 = (boundsMax - rayOrigin) / rayDir;
                    float3 tmin = min(t0, t1);
                    float3 tmax = max(t0, t1);

                    float dstA = max(max(tmin.x, tmin.y), tmin.z);
                    float dstB = min(tmax.x, min(tmax.y, tmax.z));

                    float dstToBox = max(0, dstA);
                    float dstInsideBox = max(0, dstB - dstToBox);
                    return float2(dstToBox, dstInsideBox);
                }
                //浓度（云密度）采样
                float sampleDensity(float3 position){

                    float3 uvw = position * _DensityNoiseScale + _DensityNoiseOffset;
                    float density = tex3D(_DensityNoiseTex, uvw).r;

                    float3 erodeUVW = position * _DensityErode_Scale + _DensityErode_Offset;
                    float erode = tex3D(_DensityErodeTex, erodeUVW).r * _DensityErode;

                    float edgeToX = min(_EdgeSoftnessThreshold.x, min(position.x - _BoundsMin.x, _BoundsMax.x - position.x));
                    float edgeToZ = min(_EdgeSoftnessThreshold.z, min(position.z - _BoundsMin.z, _BoundsMax.z - position.z));
                    float edgeToY = min(_EdgeSoftnessThreshold.y, min(position.y - _BoundsMin.y, _BoundsMax.y - position.y));
                    float softness = edgeToX/ _EdgeSoftnessThreshold.x * edgeToZ / _EdgeSoftnessThreshold.x * edgeToY / _EdgeSoftnessThreshold.y;

                    density = max(0, density - erode) * _DensityScale * softness * softness;
                                        return density;
                }
                
                float LightPathDensity(float3 position, int stepCount){
                    /* sample density from given point to light 
                       within target step count */

                    // URP的主光源位置的定义名字换了一下
                    float3 dirToLight = _MainLightPosition.xyz;

                    /* 这里的给传入的方向反向了一下是因为，rayBoxDst的计算是要从
                       目标点到体积，而采样时，则是反过来，从position出发到主光源*/
                    float dstInsideBox = rayBoxDst(_BoundsMin, _BoundsMax, position, dirToLight).y;

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

                    // 碰撞体积计算
                    float2 rayBoxInfo = rayBoxDst(_BoundsMin, _BoundsMax, rayPosition, rayDir);
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
                            const float density_to_light = LightPathDensity(currentPoint, 8);
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
                    
                    
                    // // 采样主纹理
                    // half4 albedo = _MainTex.Sample(sampler_MainTex, IN.uv);
                    //
                    // // 重建世界坐标 同一个屏幕像素对应的世界方向会改变
                    // float3 worldPosition = GetWorldPosition(IN.pos);
                    // float3 rayPosition = _WorldSpaceCameraPos.xyz;
                    // float3 worldViewVector = worldPosition - rayPosition;
                    // float3 rayDir = normalize(worldViewVector);
                    //
                    // // 简单的RayMarching测试
                    // float3 stepVec = rayDir * 0.5;                      // 步进向量，它由长度值乘方向得到
                    // float3 currentPoint = rayPosition;                  // 要采样的世界坐标，初始位置为相机的位置
                    // float totalDensity = 0;                             // 总浓度
                    // for(int i = 0; i < 128; i ++){
                    //     // 将测试点向前rayDir方向推移小一段距离
                    //     currentPoint += stepVec;
                    //
                    //     // 检测给定的点是否处于一个长宽高为10的正方体内部
                    //     if(currentPoint.x > 0 && currentPoint.y > 0 && currentPoint.z > 0 &&
                    //        currentPoint.x < 10 && currentPoint.y < 10 && currentPoint.z < 10)
                    //         totalDensity += 0.02;
                    // }
                    // return albedo + totalDensity;
                
                
            ENDHLSL
        }
    }
}