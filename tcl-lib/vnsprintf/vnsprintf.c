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

void my_printf(const char *str, int retcode, ...){
    char *buffer;
    va_list args, args1;
    va_start(args, retcode);
    va_copy(args1, args);   /* copy va_list object */
    size_t buffersize = vsnprintf(NULL,0 , str, args) + 1; // test buffersize
    va_end(args);
    buffer = malloc(buffersize);
    if (buffer == NULL) {
        printf("No memory for buffer!\n");
    }
    vsnprintf(buffer, buffersize, str, args1); // return the str
    va_end(args1);
    printf ("%s", buffer);
    free(buffer);
}

int main(int argc, const char * argv[]) {
    // insert code here...
    my_printf("%s: %d\n", 0, "Starter", 8);
    return 0;
}