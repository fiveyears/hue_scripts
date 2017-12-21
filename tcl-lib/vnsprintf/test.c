//
//  main.c
//  vnsprintf
//
//  Created by Ivo Döhler on 15.12.17.
//  Copyright © 2017 fiveyears. All rights reserved.
//

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <math.h>
#include "color.h"


void ppp () {
    const char *rgbString = "red";
    printf ("RGB: %s\n", rgbString);
    char *strs[4] = {"LCT001", "LCT010", "LLC005", "dummy"};
    const char *model, *rgb, *xy1;    
    int i;
    for (i = 0; i < 4; i++) {
        model = strs[i];
        xy1 = calcXY(model, rgbString);
        printf ("Model: %s, xy: %s\n", model, xy1 );
    }
    printf ("\n");
    const char *xy = "0.6920,0.3080";
    for (i = 0; i < 4; i++) {
        model = strs[i];
        rgb = calcRGB(model, xy);
        xy1 = calcXY(model, rgb);
        printf ("Model: %s, xy before: %s, xy after: %s, rgb: %s\n", model, xy, xy1, rgb);
     }
    //listColors();
    xy1 = calcXY("LCT010", "ff0000");
    rgb = calcRGB("LCT010", xy1);
    printf("%s %s\n",xy1,rgb);
    const char *s = realXY ("0.6920,0.3080, 8.0", "LCT001");
    printf("%s\n", s);
    s = gamutForModel ("LCT001");
    printf("%s\n", s);
    const char *lc = listColors("");
    printf("%s\n", lc);
    printf("%s %s\n", "red", realRGB("#FF0000"));
    exit(0);
}



int main(int argc, const char * argv[]) {
    // insert code here...
    ppp( );
    return 0;
}