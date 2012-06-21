uniform sampler2D texture;

uniform float line;

uniform int persistance;
uniform float bottomValue;
uniform float range;

void main()
{
    // Get an address into the texture for this vertex
    gl_TexCoord[0].x = gl_Vertex.x;
    gl_TexCoord[0].y = line;
    
    // Retreive the value from the texture and scale
    float value = texture2D(texture, gl_TexCoord[0].xy).a;
    float zeroCorrected = value - bottomValue;
    float scaled = zeroCorrected / range;
    
    // Copy inputs for the fragment processor
//    gl_TexCoord[0].xy = vec2(0.,0.);
	gl_FrontColor = gl_Color;
    
    // Compute a new vertex location according to the value
    vec4 tempPos = gl_Vertex;
    tempPos.y = scaled;
	gl_Position = gl_ModelViewProjectionMatrix * tempPos;
}
