
attribute vec4 position;

attribute vec2 textureCoord;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

varying lowp vec2 m_textureCoord;

void main()
{
    m_textureCoord = textureCoord;
    
	gl_Position =  position;
}

