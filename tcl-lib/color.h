
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

const char* realXY (const char *XY, const char *model) ;
const char* gamutForModel (const char* model);
const char* calcRGB (const char *model, const char *xy);
const char* realRGB (const char *rgb);
const char* calcXY (const char *model, const char *rgb);
const char* listColors (const char *start);

