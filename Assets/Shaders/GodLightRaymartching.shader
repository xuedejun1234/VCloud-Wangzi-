Shader "Unlit/GodLightRaymartching"
{
    Properties
    {
        // x = (1 - g*g) / (4*pi), y = 1 + g*g, z = 2*g. Default g = 0.8.
        _MieScatteringFactor ("Mie Scattering Coefficients", Vector) = (0.02865, 1.64, 1.6, 0)
        _ExtinctionFactor ("Extinction Factor", Range(0, 2)) = 0.2
        _ScatteringStrength ("Scattering Strength", Range(0, 1)) = 0.03
        _RayMarchingStepCount ("Ray Marching Steps", Range(8, 128)) = 32
        _TintColor ("Tint Color", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        ZTest Always
        ZWrite Off
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float3 _MieScatteringFactor;
            float _ExtinctionFactor;
            float _ScatteringStrength;
            float _RayMarchingStepCount;
            float4 _TintColor;

            float GetLightAttenuation(float3 positionWS)
            {
                float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
                return MainLightRealtimeShadow(shadowCoord);
            }

            float MieScatteringFunc(float3 lightDir, float3 rayDir)
            {
                float cosTheta = clamp(dot(lightDir, -rayDir), -1.0, 1.0);
                float denominator = max(
                    _MieScatteringFactor.y - _MieScatteringFactor.z * cosTheta,
                    1e-4
                );
                return _MieScatteringFactor.x / pow(denominator, 1.5);
            }

            float3 RayMarching(float3 cameraPos, float3 rayDir, float rayLength)
            {
                const float density = 0.8;
                int stepCount = clamp((int)round(_RayMarchingStepCount), 8, 128);
                float stepLength = rayLength / stepCount;
                float3 stepVec = rayDir * stepLength;
                float3 currentPos = cameraPos + stepVec * 0.5;

                Light mainLight = GetMainLight();
                float3 lightDir = normalize(-mainLight.direction);
                float phase = MieScatteringFunc(lightDir, rayDir);
                float transmittance = 1.0;
                float3 scatteredLight = 0.0;

                [loop]
                for (int i = 0; i < stepCount; ++i)
                {
                    float shadow = GetLightAttenuation(currentPos);
                    float extinctionPerLength = _ExtinctionFactor * density;
                    float stepTransmittance = exp(-extinctionPerLength * stepLength);
                    float scatterIntegral;

                    if (extinctionPerLength > 1e-4)
                    {
                        scatterIntegral = _ScatteringStrength * density
                            * (1.0 - stepTransmittance) / extinctionPerLength;
                    }
                    else
                    {
                        scatterIntegral = _ScatteringStrength * density * stepLength;
                    }

                    scatteredLight += mainLight.color * _TintColor.rgb
                        * (shadow * phase * scatterIntegral * transmittance);
                    transmittance *= stepTransmittance;
                    currentPos += stepVec;
                }

                return scatteredLight;
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float2 uv = input.positionCS.xy / _ScaledScreenParams.xy;
                float rawDepth = SampleSceneDepth(uv);

                #if !UNITY_REVERSED_Z
                    rawDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1.0, rawDepth);
                #endif

                float3 cameraPos = GetCameraPositionWS();
                float3 worldPos = ComputeWorldSpacePosition(
                    uv, rawDepth, UNITY_MATRIX_I_VP
                );
                float3 rayVector = worldPos - cameraPos;
                float rayLength = length(rayVector);
                float3 rayDir = rayVector / max(rayLength, 1e-5);

                half4 sceneColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                float3 godLight = RayMarching(cameraPos, rayDir, rayLength);
                return half4(sceneColor.rgb + godLight, sceneColor.a);
            }
            ENDHLSL
        }
    }
}
