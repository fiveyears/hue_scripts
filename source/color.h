struct CGPoint {
    float x;
    float y;
};
typedef struct CGPoint CGPoint;

struct ColorPoints {
    CGPoint red;
    CGPoint green;
    CGPoint blue;
};
typedef struct ColorPoints ColorPoints;

struct Color {
    float red;
    float green;
    float blue;
};
typedef struct Color Color;

const char* realXY (float x, float y, float redX, float redY, float greenX, float greenY, float blueX, float blueY) ;
const char* calcRGB (float x, float y, float redX, float redY, float greenX, float greenY, float blueX, float blueY);
const char* realRGB (const char *rgb);
const char* calcXY (const char *rgb, float redX, float redY, float greenX, float greenY, float blueX, float blueY);
const char* listColors (const char *start);

