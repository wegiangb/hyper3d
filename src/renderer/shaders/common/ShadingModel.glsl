#pragma require Constants
#pragma require GBuffer
#pragma require Materials

struct PointLightBRDFParameters
{
    float nhDot;
    float nlDot;
    float nvDot;
    float hlDot;
};

struct UniformLightBRDFParameters
{
    float nvDot;
};

struct MaterialInfo
{
    vec3 albedo;
    float roughness;
    float metallic;
    float specular;

    float clearCoatRoughness;

    float materialId;
};

float evaluateGGXSpecularDistribution(float nhDot, highp float roughness)
{
    // Walter et al. 2007, "Microfacet models for refraction through rough surfaces"
    // http://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf
    highp float a = roughness * roughness;
    highp float aa = a * a;
    highp float t = nhDot * nhDot * (aa - 1.) + 1.;
    return aa /
        (t * t + 1.e-20);
}

float evaluateLambertDiffuse(float nlDot)
{
    return 1.;
}

float evaluateDisneyPrincipledDiffuse(float nlDot, float nvDot, float hlDot, float roughness)
{
    float fd90m1 = -0.5 + hlDot * hlDot * 2. * roughness;
    float f1a = 1. - nlDot, f2a = 1. - nvDot;
    float f1b = f1a * f1a, f2b = f2a * f2a;
    float f1 = f1a * f1b * f1b, f2 = f2a * f2b * f2b;
    return (1. + fd90m1 * f1) * (1. + fd90m1 * f2) * nlDot;
}

float evaluateSchlickFresnel(float hlDot)
{
    float t = 1. - hlDot;
    float tt = t * t;
    return tt * tt * t;
}

// evaluateXXXGeometryShadowing evaluates G(l, v, h) / (n dot v).
float evaluateBeckmannGeometryShadowing(float nlDot, float nvDot, float roughness)
{
    // http://graphicrants.blogspot.jp/2013/08/specular-brdf-reference.html
    float lct = .5 / (roughness * sqrt(1. - nlDot * nlDot) + 0.00001);
    float vct = .5 / (roughness * sqrt(1. - nvDot * nvDot) + 0.00001);
    float lc = lct * nlDot, vc = vct * nvDot;
    float a = 3.353 * lc + 2.181 * lc * lc; // not typo
    a *= 3.353 * vct + 2.181 * vct * vc;
    float b = 1. + 2.276 * lc + 2.577 * lc * lc;
    b *= 1. + 2.276 * vc + 2.577 * vc * vc;
    return a / b;
}
float evaluateBeckmannGeometryShadowingSingleSide(float nlDot, float roughness)
{
    // http://graphicrants.blogspot.jp/2013/08/specular-brdf-reference.html
    float lct = .5 / (roughness * sqrt(1. - nlDot * nlDot) + 0.00001);
    float lc = lct * nlDot;
    float a = 3.353 * lc + 2.181 * lc * lc; // not typo
    float b = 1. + 2.276 * lc + 2.577 * lc * lc;
    return a / b;
}

bool isMaterialClearCoat(MaterialInfo material)
{
    return material.materialId == MaterialIdClearCoat;
}

vec3 evaluatePointLight(
    PointLightBRDFParameters params,
    MaterialInfo material,
    vec3 lightColor)
{
    if (material.materialId == MaterialIdUnlit) {
        return vec3(0.);
    }
    if (params.nlDot <= 0.) {
        return vec3(0.);
    }

    float fresnel = evaluateSchlickFresnel(params.hlDot);

    vec3 minRefl = mix(vec3(material.specular), material.albedo, material.metallic);
    vec3 refl = mix(minRefl, vec3(1.), fresnel);

    float diffuseMix = 1. - mix(mix(material.specular, 1., material.metallic), 1., fresnel);
    diffuseMix *= evaluateDisneyPrincipledDiffuse(params.nlDot, params.nvDot, params.hlDot, material.roughness);

    float specular = evaluateGGXSpecularDistribution(params.nhDot, material.roughness);
    specular *= evaluateBeckmannGeometryShadowing(params.nlDot, params.nvDot, material.roughness);

    diffuseMix *= params.nlDot; specular *= params.nlDot;

    vec3 diffuse = material.albedo;

    vec3 final = diffuse * diffuseMix + refl * specular;

    // clear coat
    if (isMaterialClearCoat(material)) {
        float ccspecular = evaluateGGXSpecularDistribution(params.nhDot, material.clearCoatRoughness);
        ccspecular *= evaluateBeckmannGeometryShadowing(params.nlDot, params.nvDot, material.clearCoatRoughness);
        ccspecular *= params.nlDot;
        float refl = mix(0.03, 1., fresnel);
        final = mix(final, vec3(ccspecular), refl);
    }

    return final * lightColor;
}

vec3 evaluateUniformLight(
    UniformLightBRDFParameters params,
    MaterialInfo material,
    vec3 lightColor)
{
    if (material.materialId == MaterialIdUnlit) {
        return vec3(0.);
    }

    // FIXME: verify this model
    float fresnel = evaluateSchlickFresnel(params.nvDot);

    vec3 minRefl = mix(vec3(material.specular), material.albedo, material.metallic);
    vec3 refl = mix(minRefl, vec3(1.), fresnel);

    float diffuseMix = 1. - mix(mix(material.specular, 1., material.metallic), 1., fresnel);

    vec3 diffuse = material.albedo;

    vec3 final = diffuse * diffuseMix;
    return final * lightColor;
}

vec4 evaluateReflection(
    float nvDot,
    MaterialInfo material)
{
    if (material.materialId == MaterialIdUnlit) {
        return vec4(0.);
    }

    // assume h = n now
    float fresnel = evaluateSchlickFresnel(nvDot);

    vec3 minRefl = mix(vec3(material.specular), material.albedo, material.metallic);
    vec4 refl = vec4(mix(minRefl, vec3(1.), fresnel), 1.);

    refl *= evaluateBeckmannGeometryShadowingSingleSide(nvDot, material.roughness);

    return refl;
}

vec2 evaluateReflectionForClearCoat(
    float nvDot,
    MaterialInfo material)
{
    if (!isMaterialClearCoat(material)) {
        return vec2(0.);
    }

    // assume h = n now
    float fresnel = evaluateSchlickFresnel(nvDot);

    float refl = mix(0.03, 1., fresnel);

    float reflShadowed = refl * 
        evaluateBeckmannGeometryShadowing(nvDot, nvDot, material.clearCoatRoughness); // FIXME: optimize?

    return vec2(reflShadowed, refl);
}

PointLightBRDFParameters computePointLightBRDFParameters(
    vec3 normal, vec3 light, vec3 view)
{
    vec3 halfVec = normalize(light + view);
    return PointLightBRDFParameters(
        clamp(dot(normal, halfVec), 0., 1.),
        clamp(dot(normal, light), 0., 1.),
        clamp(dot(normal, view), 0., 1.),
        clamp(dot(halfVec, light), 0., 1.));
}

UniformLightBRDFParameters computeUniformLightBRDFParameters(
    vec3 normal, vec3 view)
{
    UniformLightBRDFParameters ret;
    ret.nvDot = clamp(dot(normal, view), 0., 1.);
    return ret;
}

MaterialInfo getMaterialInfoFromGBuffer(GBufferContents g)
{
    return MaterialInfo(
        g.albedo,
        mix(0.001, 1., g.roughness),
        g.metallic,
        g.specular,

        mix(0.001, 1., g.materialParam), // clearCoatRoughness

        g.materialId);
}

