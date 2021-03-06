
attribute vec2 a_position;
varying vec2 v_texCoord;
varying vec2 v_viewDir;
uniform vec2 u_viewDirCoefX;
uniform vec2 u_viewDirCoefY;
uniform vec2 u_viewDirOffset;
uniform highp float u_depthValue;

void main()
{
    gl_Position = vec4(a_position, u_depthValue, 1.);
    v_texCoord = a_position * 0.5 + 0.5;

    v_viewDir = u_viewDirOffset;
    v_viewDir += u_viewDirCoefX * a_position.x;
    v_viewDir += u_viewDirCoefY * a_position.y;
}
