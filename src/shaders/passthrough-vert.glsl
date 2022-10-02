#version 300 es

precision highp float;

in vec4 vs_Pos;

void main() {
	// Pass info into fragment shader
	gl_Position = vs_Pos;
}