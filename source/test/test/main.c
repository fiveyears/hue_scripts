//
//  main.c
//  test
//
//  Created by Ivo Döhler on 14.05.22.
//

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

int isNumber(char *text)
{
    unsigned long j;
    j = strlen(text);
    while(j--)
    {
//        if(text[j] >= '0' && text[j] <= '9')
        if( isdigit(text[j]))
            continue;
        return 0;
    }
    return 1;
}
const char* stringOrNumber (char* text, int places) {
    static char str[300] = "\0";
    if (isNumber(text)) {
        sprintf(str, "Number: %0*i", places, atoi(text) );
    } else {
        sprintf(str, "Char: %s", text );
    }
    return str;
}

int main(int argc, const char * argv[]) {
    char* s = "4";
    // insert code here...
    int places = 3;
    
    printf("%s\n", stringOrNumber(s, places));
    return 0;
}
