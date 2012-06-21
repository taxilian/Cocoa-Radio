uniform sampler2D texture;

uniform int persistance;
uniform float bottomValue;
uniform float range;

void main()
{
    float value = texture2D(texture, gl_TexCoord[0].xy).a;
    float zeroCorrected = value - bottomValue;
    float scaled = zeroCorrected / range;
    
//    gl_FragColor.r = scaled;
//    gl_FragColor.g = gl_TexCoord[0].x;
//    gl_FragColor.b = gl_TexCoord[0].y;
//    gl_FragColor.a = 1.;
    
	gl_FragColor = gl_Color;
}
