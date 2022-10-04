#version 300 es

in vec4 vs_Pos;

out vec4 fs_Pos;

const vec4 lightPos = vec4(5, 5, 3, 1);

void main()
{
    fs_Pos = vs_Pos;

    gl_Position = vec4(vs_Pos);
}
