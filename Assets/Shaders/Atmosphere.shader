Shader "PostProcessing/Atmosphere"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _PlanetRadius ("Planet Radius", float) = 2.5
        _AtmosphereRadius ("Atmosphere Radius", float) = 1.
        _DensityFalloff ("Density Falloff", float) = 2.
        _DirToSun ("Dir To Sun", Vector) = (1, 0, 0, 0)
        
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #define MAX_FLOAT 3.402823466e+38

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 viewVector : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                float3 viewVector = mul(unity_CameraInvProjection, float4(v.uv.xy * 2 - 1, 0, -1));
                o.viewVector = mul(unity_CameraToWorld, float4(viewVector, 0));
                return o;
            }

            sampler2D _MainTex;
            float _PlanetRadius;
            float _AtmosphereRadius;
            float _DensityFalloff;
            float4 _DirToSun;
            float3 _ScatteringCoeff;
            
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

            // return .x: viewPoint to Atmosphere distance
            // return .y: length of viewRay inside the Atmoshpere
            float2 raySphere(float3 sphereCentre, float sphereRadius, float3 rayOrigin, float3 rayDir) {
		        float3 offset = rayOrigin - sphereCentre;
		        float a = 1; 
		        float b = 2 * dot(offset, rayDir);
		        float c = dot (offset, offset) - sphereRadius * sphereRadius;
		        float d = b * b - 4 * a * c;

		        
		        if (d > 0) {
			        float s = sqrt(d);
			        float dstToSphereNear = max(0, (-b - s) / (2 * a));
			        float dstToSphereFar = (-b + s) / (2 * a);

			        if (dstToSphereFar >= 0) {
				        return float2(dstToSphereNear, dstToSphereFar - dstToSphereNear);
			        }
		        }
		        return float2(MAX_FLOAT, 0);
	        }

            float densityAtPoint(float3 samplePoint)
            {
                float atmosphereHeight = length(samplePoint - float3(0, 0, 0)) - _PlanetRadius;
                float height01 = atmosphereHeight / (_AtmosphereRadius - _PlanetRadius);
                float localDensity = exp(-height01 * _DensityFalloff) * (1 - height01);
                return localDensity;
            }

            // Density integration
            float atmoThickness(float3 rayOrign, float3 rayDir, float rayLength)
            {
                int iterationNum = 16;
                float stepSize = rayLength / (iterationNum - 1);

                float3 samplePoint = rayOrign;
                float thickness = 0;

                for (int i = 0; i < iterationNum; i++)
                {
                    thickness += densityAtPoint(samplePoint) * stepSize;
                    samplePoint += rayDir * stepSize;
                }

                return thickness;
            }
            
            float3 calculateLight(float3 rayOrigin, float3 rayDir, float rayLength, out float originalTransmittance)
            {
                float stepNum = 32;
                float3 inScatterPoint = rayOrigin;
                float stepSize = rayLength / (stepNum - 1);
                float3 inScatteredLight = 0;
                float viewRayThickness = 0;
                for (int i = 0; i < stepNum; i++)
                {
                    float sunRayLength = raySphere(float3(0, 0, 0), _AtmosphereRadius, inScatterPoint, _DirToSun).y;
                    float sunRayThickness = atmoThickness(inScatterPoint, _DirToSun, sunRayLength);
                    viewRayThickness = atmoThickness(inScatterPoint, -rayDir, stepSize * i);
                    float3 transmittance = exp(-(sunRayThickness + viewRayThickness) * _ScatteringCoeff);
                    float localDensity = densityAtPoint(inScatterPoint); // current point density

                    inScatteredLight += localDensity * transmittance * _ScatteringCoeff * stepSize;
                    inScatterPoint += rayDir * stepSize;
                }

                originalTransmittance = exp(-viewRayThickness);

                return inScatteredLight;
            }

            
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 sceneColor = tex2D(_MainTex, i.uv);
                float sceneDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv)) * length(i.viewVector);

                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDir = normalize(i.viewVector);
                float2 hitInfo = raySphere(float3(0, 0 , 0), _AtmosphereRadius, rayOrigin, rayDir);
                float dstToAtmosphere = hitInfo.x;
                float dstInsideAtmosphere = min(hitInfo.y, sceneDepth - dstToAtmosphere);
                float c = dstInsideAtmosphere / (_AtmosphereRadius * 2);

                float transmittance = 1;
                if (dstInsideAtmosphere > 0)
                {
                    float3 startPoint = rayOrigin + rayDir * dstToAtmosphere;
                    float3 light = calculateLight(startPoint, rayDir, dstInsideAtmosphere, transmittance);
                    
                    return float4(light, 1) + transmittance * sceneColor;
                }
                return sceneColor;
            }
            ENDCG
        }
    }
}
