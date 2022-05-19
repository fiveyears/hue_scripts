#include "jsmn.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>

char objectName[300];
char arrayName[300];
int places;
// int max_places = 1;

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
        sprintf(str, "%0*i", places, atoi(text) );
    } else {
        sprintf(str, "%s", text );
    }
    return str;
}


static inline void *realloc_it(void *ptrmem, size_t size) {
  void *p = realloc(ptrmem, size);
  if (!p) {
    free(ptrmem);
    fprintf(stderr, "realloc(): errno=%d\n", errno);
  }
  return p;
}

/*
 * An example of reading JSON from stdin and printing its content to stdout.
 * The output looks like YAML, but I'm not sure if it's really compatible.
 */

static int dump(const char *js, jsmntok_t *t, size_t count, int indent) {
  int i, j, k;
  jsmntok_t *key;
  if (count == 0) {
    return 0;
  }
  if (t->type == JSMN_PRIMITIVE) {
    printf("%.*s", t->end - t->start, js + t->start);
    return 1;
  } else if (t->type == JSMN_STRING) {
    printf("'%.*s'", t->end - t->start, js + t->start);
    return 1;
  } else if (t->type == JSMN_OBJECT) {
    printf("\n");
    j = 0;
    for (i = 0; i < t->size; i++) {
      for (k = 0; k < indent; k++) {
        printf("  ");
      }
      key = t + 1 + j;
      j += dump(js, key, count - j, indent + 1);
      if (key->size > 0) {
        printf(": ");
        j += dump(js, t + 1 + j, count - j, indent + 1);
      }
      printf("\n");
    }
    return j + 1;
  } else if (t->type == JSMN_ARRAY) {
    j = 0;
    printf("\n");
    for (i = 0; i < t->size; i++) {
      for (k = 0; k < indent - 1; k++) {
        printf("  ");
      }
      printf("   - ");
      j += dump(js, t + 1 + j, count - j, indent + 1);
      printf("\n");
    }
    return j + 1;
  }
  return 0;
}

// static int calc_places(const char *js, jsmntok_t *t, size_t count) {
//     int i, j;
//     int index = 0;
//     jsmntok_t *key;
//     if (count == 0) {
//         return 0;
//     }
//     if (t->type == JSMN_PRIMITIVE) { // numbers, true false etc.
//         return 1;
//     } else if (t->type == JSMN_STRING) {
//         return 1;
//     } else if (t->type == JSMN_OBJECT) {
//         j = 0;
//         for (i = 0; i < t->size; i++) {
//             key = t + 1 + j;
//             j += calc_places(js, key, count - j);
//             if (key->size > 0) {
//                 j += calc_places(js, t + 1 + j, count - j);
//             }
//          }
//         return j + 1;
//     } else if (t->type == JSMN_ARRAY) {
//         j = 0;
//         for (i = 0; i < t->size; i++) {
//             if (index > max_places) max_places = index;
//             index++;
//             j += calc_places(js, t + 1 + j, count - j);
//          }
//         return j + 1;
//     }
//     return 0;
// }

static int dump_tcl(const char *js, jsmntok_t *t, size_t count, int indent, const char *root, int afterColon) {
#define doppelpunkt ""
    objectName[0] = '\0'; //  maybe there is a object name
    char newRoot[2048];
    int i, j;
    //int k;
    int index = 0;
    jsmntok_t *key;
    if (count == 0) {
        return 0;
    }
    if (t->type == JSMN_PRIMITIVE) { // numbers, true false etc.
        printf("%s %.*s\n", root, t->end - t->start, js + t->start);
        return 1;
    } else if (t->type == JSMN_STRING) {
        if (afterColon == 0 ) {
            sprintf(objectName, "%.*s", t->end - t->start, js + t->start);
            sprintf(objectName, "(%s)", stringOrNumber (objectName, places));
        } else {
            printf("%s \"%.*s\"\n", root, t->end - t->start, js + t->start);
        }
        return 1;
    } else if (t->type == JSMN_OBJECT) {
        //printf("      #       object '%s' is coming '%i' \n", root, indent );
        j = 0;
        for (i = 0; i < t->size; i++) {
            //      for (k = 0; k < indent; k++) {
            //        printf("  ");
            //      }
            key = t + 1 + j;
            j += dump_tcl(js, key, count - j, indent + 1, root, 0);
            strcpy (newRoot, root);
            strcat(newRoot, objectName);
            strcpy(arrayName, newRoot);
            if (key->size > 0) {
                printf("%s", doppelpunkt);
                j += dump_tcl(js, t + 1 + j, count - j, indent + 1, newRoot, 1);
            }
            //printf("\n");
        }
        return j + 1;
    } else if (t->type == JSMN_ARRAY) {
        j = 0;
        if (t->size == 0) {
            printf("%s \"\"\n", arrayName);
        }
        for (i = 0; i < t->size; i++) {
//            for (k = 0; k < indent - 1; k++) {
//                printf("  ");
//            }
            //printf("  - "); // printf("  - ");
            strcpy (newRoot, root);
            sprintf(objectName, "(%0*i)", places, index++);
            strcat(newRoot, objectName);
            j += dump_tcl(js, t + 1 + j, count - j, indent + 1, newRoot, 1);
            //printf("\n");
        }
        return j + 1;
    }
    return 0;
}

int main(int argc, char* argv[]) {
#ifdef DEBUG
    freopen( "/Users/ivo/Dropbox/web/hue/source/jsondump/jsondump/t.txt", "r", stdin );
#endif
    long r;
    int eof_expected = 0;
    char *js = NULL;
    size_t jslen = 0;
    char buf[300000];
    
    jsmn_parser p;
    jsmntok_t *tok;
//    size_t tokcount = 12800;
    unsigned int tokcount = 12800;

    /* Prepare parser */
    jsmn_init(&p);
    
    /* Allocate some tokens as a start */
    tok = malloc(sizeof(*tok) * tokcount);
    if (tok == NULL) {
        fprintf(stderr, "malloc(): errno=%d\n", errno);
        return 3;
    }
    for (;;) {
        /* Read another chunk */
        r = fread(buf, 1, sizeof(buf), stdin);
        if (r < 0) {
            fprintf(stderr, "fread(): %ld, errno=%d\n", r, errno);
            return 1;
        }
        if (r == 0) {
            if (eof_expected != 0) {
                return 0;
            } else {
                fprintf(stderr, "fread(): unexpected EOF\n");
                return 2;
            }
        }
        
        js = realloc_it(js, jslen + r + 1);
        if (js == NULL) {
            return 3;
        }
        strncpy(js + jslen, buf, r);
        jslen = jslen + r;
        
    again:
        r = jsmn_parse(&p, js, jslen, tok, tokcount);
        if (r < 0) {
            if (r == JSMN_ERROR_NOMEM) {
                tokcount = tokcount * 2;
                tok = realloc_it(tok, sizeof(*tok) * tokcount);
                if (tok == NULL) {
                    return 3;
                }
                goto again;
            }
        } else {
            int dumpIt = 0;
            if (argc > 1) {
                dumpIt = atoi(argv[1]);
            }
            places = 1;
            if (argc > 2) {
                places = atoi(argv[2]);
                if (places == 0) places = 1;
            }
            // calc_places(js, tok, p.toknext);
            // int pl = log10(max_places)+1;
            // if (pl > places) {places = pl;}
            if (dumpIt != 0 ) {
                dump(js, tok, p.toknext, 0);
            } else {
                dump_tcl(js, tok, p.toknext, 0, "set root", 0);
                printf("set root(places) %i\n",places);
            }
            eof_expected = 1;
        }
    }
    
    return EXIT_SUCCESS;
}
