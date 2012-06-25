uniform sampler2D texture;

uniform float line;
uniform int height;
uniform int width;

uniform int average;
uniform int persistance;
uniform float bottomValue;
uniform float range;

float getValue(vec2 tex)
{
    float value = 0.;
    float inputY = tex.y;
    
    float deltaY = 1. / float(height);
    
    int i = 0;
    for(i = 0; i < average; i++) {
        // For each sample, look into the past i samples
        tex.y = inputY - (deltaY * float(i));
        
        // Wrap-around the height of the texture
        tex.y = mod(tex.y, 1.);
        
        // Retreive the sample
        float temp = texture2D(texture, tex).a;
        
        // Devide by the number of samples and accumulate
        value += temp * (1. / float(average));
    }
    
    return value;
}

void main()
{
    // Convert the normalized height coordinate into pixels
    vec2 tex;
    tex.x = gl_Vertex.x;
    tex.y = line;

    // Access the value and scale it
    float value = getValue(tex);
    float zeroCorrected = value - bottomValue;
    float scaled = zeroCorrected / range;
    
    // Copy inputs for the fragment processor
	gl_FrontColor = gl_Color;
    
    // Compute a new vertex location according to the value
    vec4 tempPos = gl_Vertex;
    tempPos.y = scaled;
	gl_Position = gl_ModelViewProjectionMatrix * tempPos;
}
