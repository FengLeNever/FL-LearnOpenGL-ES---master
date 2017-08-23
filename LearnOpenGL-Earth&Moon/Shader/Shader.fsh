
varying lowp vec2 m_textureCoord;

uniform sampler2D samplerTexture;

void main()
{
	gl_FragColor = texture2D(samplerTexture,m_textureCoord);
}
