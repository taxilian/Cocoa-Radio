uniform sampler2D texture;

uniform int persistance;
uniform float bottomValue;
uniform float range;

void main()
{
    vec2 coords = vec2(1024.,1024.);
    float value = texture2D(texture, coords).a;
    float zeroCorrected = value - bottomValue;
    float scaled = zeroCorrected / range;
    
	gl_FragColor = gl_Color;
}
