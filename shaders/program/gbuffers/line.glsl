#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"

#ifdef fsh

in VSOUT 
{
    vec4 vertexColor;
} vsout;

/* DRAWBUFFERS:10 */
layout (location = 0) out vec4 colortex7Out;

void main ()
{
    if (any(greaterThan(gl_FragCoord.xy, screenSize))) discard;

    colortex7Out = vsout.vertexColor;
}

#endif

#ifdef vsh

out VSOUT 
{
    vec4 vertexColor;
} vsout;

vec4 ftransformLine()
{
    vec4 lineDir = mat3x4(gl_ProjectionMatrix) * mat3(gl_ModelViewMatrix) * gl_Normal;

  	vec4 linePosStart = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
  	vec4 linePosEnd = linePosStart + lineDir;

    if (linePosStart.w <= 0.0) linePosStart -= (linePosStart.w - 0.00001) * vec4(lineDir.xyz / lineDir.w, 1.0);
    if (linePosEnd.w <= 0.0) linePosEnd += (linePosEnd.w - 0.00001) * vec4(lineDir.xyz / lineDir.w, 1.0);

 	vec3 ndc1 = linePosStart.xyz / linePosStart.w;
  	vec3 ndc2 = linePosEnd.xyz / linePosEnd.w;

  	vec2 lineScreenDirection = texelSize * normalize((ndc2.xy - ndc1.xy) * renderSize);
  	vec2 lineOffset = lineWidth * vec2(-lineScreenDirection.y, lineScreenDirection.x);
	
  	if (lineOffset.x < 0.0) {
    	lineOffset *= -1.0;
    }

  	if ((gl_VertexID & 1) == 0) {
        return vec4((ndc1 + vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);
    } else {
        return vec4((ndc1 - vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);
    }
}

void main ()
{   
    gl_Position = ftransformLine();

    gl_Position.xy = mix(-gl_Position.ww, gl_Position.xy, TAAU_RENDER_SCALE);
    gl_Position.xy += gl_Position.w * taaOffset;
    
    vsout.vertexColor = gl_Color;
}

#endif