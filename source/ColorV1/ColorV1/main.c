//
//  main.c
//  ColorV1
//
//  Created by Ivo Döhler on 15.04.22.
//

#include <stdio.h>
#include "colorv1.h"
void rrr (char* model, char* rgb) {
    const char* realR = realRGB(rgb);
    printf("realRGB for %s: %s\n", rgb, realR);
    printf("calcXY for %s: %s\n", realR, calcXY(model, realR));

}
int main(int argc, const char * argv[]) {
    // insert code here...
    char* model = "LCT001";
    printf("Gamut for model %s: %s\n\n", model, gamutForModel(model));
    rrr(model, "red");
    rrr(model, "blue");
    rrr(model, "green");
    return 0;
}
