
varying lowp vec2 m_textureCoord;
precision mediump float;
uniform sampler2D SamplerY;
uniform sampler2D SamplerUV;

uniform mat3 colorConversionMatrix;

void main()
{
    mediump vec3 yuv;
    lowp vec3 rgb;
    
    // Subtract constants to map the video range start at 0
    yuv.x = (texture2D(SamplerY, m_textureCoord).r);// - (16.0/255.0));
    yuv.yz = (texture2D(SamplerUV, m_textureCoord).ra - vec2(0.5, 0.5));
    
    rgb = colorConversionMatrix * yuv;
    
    gl_FragColor = vec4(rgb,1);
}
