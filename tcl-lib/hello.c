#include <string.h>  /* strlen() */
#include <tcl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <errno.h>
#include <assert.h>
#include "jsmn.h"
#include "color.h"

const char* array_name = "ar_";
int *ar;
long places = 2;
long removebrackets = 1;
Tcl_Obj *obj_str;
Tcl_Interp *interpreter;

static const char *JSON_STRING =
"{\"1\":{\"state\":{\"on\":false,\"bri\":254,\"hue\":34079,\"sat\":251,\"effect\":\"none\",\"xy\":[0.3144,0.3301],\"ct\":153,\"alert\":\"none\",\"colormode\":\"xy\",\"mode\":\"homeautomation\",\"reachable\":true},\"swupdate\":{\"state\":\"noupdates\",\"lastinstall\":\"2017-11-30T13:17:04\"},\"type\":\"Extended color light\",\"name\":\"Hue TV\",\"modelid\":\"LCT001\",\"manufacturername\":\"Philips\",\"capabilities\":{\"streaming\":{\"renderer\":true,\"proxy\":false}},\"uniqueid\":\"00:17:88:01:00:fc:1f:eb-0b\",\"swversion\":\"5.105.0.21169\"},\"2\":{\"state\":{\"on\":false,\"bri\":127,\"hue\":8904,\"sat\":106,\"effect\":\"none\",\"xy\":[0.4647,0.3824],\"ct\":375,\"alert\":\"none\",\"colormode\":\"xy\",\"mode\":\"homeautomation\",\"reachable\":true},\"swupdate\":{\"state\":\"noupdates\",\"lastinstall\":\"2017-11-30T13:18:04\"},\"type\":\"Extended color light\",\"name\":\"D2\",\"modelid\":\"LCT001\",\"manufacturername\":\"Philips\",\"capabilities\":{\"streaming\":{\"renderer\":true,\"proxy\":false}},\"uniqueid\":\"00:17:88:01:00:f9:66:65-0b\",\"swversion\":\"5.105.0.21169\"},\"3\":{\"state\":{\"on\":false,\"bri\":117,\"hue\":8904,\"sat\":106,\"effect\":\"none\",\"xy\":[0.4647,0.3824],\"ct\":375,\"alert\":\"none\",\"colormode\":\"xy\",\"mode\":\"homeautomation\",\"reachable\":true},\"swupdate\":{\"state\":\"noupdates\",\"lastinstall\":\"2017-11-30T13:17:58\"},\"type\":\"Extended color light\",\"name\":\"D3\",\"modelid\":\"LCT001\",\"manufacturername\":\"Philips\",\"capabilities\":{\"streaming\":{\"renderer\":true,\"proxy\":false}},\"uniqueid\":\"00:17:88:01:00:fc:1a:5e-0b\",\"swversion\":\"5.105.0.21169\"},\"4\":{\"state\":{\"on\":false,\"bri\":254,\"hue\":7808,\"sat\":151,\"effect\":\"none\",\"xy\":[0.4708,0.4071],\"ct\":389,\"alert\":\"none\",\"colormode\":\"xy\",\"mode\":\"homeautomation\",\"reachable\":true},\"swupdate\":{\"state\":\"noupdates\",\"lastinstall\":\"2017-11-30T13:17:53\"},\"type\":\"Extended color light\",\"name\":\"S3\",\"modelid\":\"LCT010\",\"manufacturername\":\"Philips\",\"capabilities\":{\"streaming\":{\"renderer\":true,\"proxy\":true}},\"uniqueid\":\"00:17:88:01:02:46:7b:08-0b\",\"swversion\":\"1.29.0_r21169\",\"swconfigid\":\"6A139B19\",\"productid\":\"Philips-LCT010-1-A19ECLv4\"},\"5\":{\"state\":{\"on\":false,\"bri\":254,\"hue\":7808,\"sat\":151,\"effect\":\"none\",\"xy\":[0.4708,0.4071],\"ct\":389,\"alert\":\"none\",\"colormode\":\"xy\",\"mode\":\"homeautomation\",\"reachable\":true},\"swupdate\":{\"state\":\"noupdates\",\"lastinstall\":\"2017-11-30T13:17:47\"},\"type\":\"Extended color light\",\"name\":\"Hue go\",\"modelid\":\"LLC020\",\"manufacturername\":\"Philips\",\"capabilities\":{\"streaming\":{\"renderer\":true,\"proxy\":true}},\"uniqueid\":\"00:17:88:01:01:19:95:04-0b\",\"swversion\":\"5.105.0.21169\"},\"6\":{\"state\":{\"on\":false,\"bri\":254,\"hue\":39649,\"sat\":112,\"effect\":\"none\",\"xy\":[0.3104,0.3302],\"alert\":\"none\",\"colormode\":\"xy\",\"mode\":\"homeautomation\",\"reachable\":true},\"swupdate\":{\"state\":\"noupdates\",\"lastinstall\":\"2017-11-30T13:17:42\"},\"type\":\"Color light\",\"name\":\"Hue iris\",\"modelid\":\"LLC010\",\"manufacturername\":\"Philips\",\"capabilities\":{\"streaming\":{\"renderer\":true,\"proxy\":false}},\"uniqueid\":\"00:17:88:01:00:0c:ca:cb-0b\",\"swversion\":\"5.105.1.21778\"},\"7\":{\"state\":{\"on\":false,\"bri\":254,\"hue\":25600,\"sat\":254,\"effect\":\"none\",\"xy\":[0.1700,0.7000],\"ct\":153,\"alert\":\"select\",\"colormode\":\"hs\",\"mode\":\"homeautomation\",\"reachable\":true},\"swupdate\":{\"state\":\"noupdates\",\"lastinstall\":\"2017-11-30T13:17:36\"},\"type\":\"Extended color light\",\"name\":\"S1\",\"modelid\":\"LCT010\",\"manufacturername\":\"Philips\",\"capabilities\":{\"streaming\":{\"renderer\":true,\"proxy\":true}},\"uniqueid\":\"00:17:88:01:02:3c:b2:9c-0b\",\"swversion\":\"1.29.0_r21169\",\"swconfigid\":\"6A139B19\",\"productid\":\"Philips-LCT010-1-A19ECLv4\"},\"8\":{\"state\":{\"on\":false,\"bri\":254,\"hue\":7808,\"sat\":151,\"effect\":\"none\",\"xy\":[0.4708,0.4071],\"ct\":389,\"alert\":\"none\",\"colormode\":\"xy\",\"mode\":\"homeautomation\",\"reachable\":true},\"swupdate\":{\"state\":\"noupdates\",\"lastinstall\":\"2017-11-30T13:17:30\"},\"type\":\"Extended color light\",\"name\":\"S2\",\"modelid\":\"LCT010\",\"manufacturername\":\"Philips\",\"capabilities\":{\"streaming\":{\"renderer\":true,\"proxy\":true}},\"uniqueid\":\"00:17:88:01:02:34:85:8d-0b\",\"swversion\":\"1.29.0_r21169\",\"swconfigid\":\"6A139B19\",\"productid\":\"Philips-LCT010-1-A19ECLv4\"},\"9\":{\"state\":{\"on\":false,\"bri\":142,\"hue\":5353,\"sat\":106,\"effect\":\"none\",\"xy\":[0.4647,0.3824],\"ct\":375,\"alert\":\"none\",\"colormode\":\"xy\",\"mode\":\"homeautomation\",\"reachable\":true},\"swupdate\":{\"state\":\"noupdates\",\"lastinstall\":\"2017-11-30T13:17:24\"},\"type\":\"Extended color light\",\"name\":\"D1\",\"modelid\":\"LCT010\",\"manufacturername\":\"Philips\",\"capabilities\":{\"streaming\":{\"renderer\":true,\"proxy\":true}},\"uniqueid\":\"00:17:88:01:02:32:e1:d7-0b\",\"swversion\":\"1.29.0_r21169\",\"swconfigid\":\"6A139B19\",\"productid\":\"Philips-LCT010-1-A19ECLv4\"},\"10\":{\"state\":{\"on\":false,\"bri\":254,\"hue\":41441,\"sat\":75,\"effect\":\"none\",\"xy\":[0.3146,0.3303],\"ct\":156,\"alert\":\"none\",\"colormode\":\"xy\",\"mode\":\"homeautomation\",\"reachable\":true},\"swupdate\":{\"state\":\"noupdates\",\"lastinstall\":\"2017-11-30T13:17:19\"},\"type\":\"Extended color light\",\"name\":\"TV 3\",\"modelid\":\"LCT010\",\"manufacturername\":\"Philips\",\"capabilities\":{\"streaming\":{\"renderer\":true,\"proxy\":true}},\"uniqueid\":\"00:17:88:01:02:3c:92:3d-0b\",\"swversion\":\"1.29.0_r21169\",\"swconfigid\":\"6A139B19\",\"productid\":\"Philips-LCT010-1-A19ECLv4\"},\"11\":{\"state\":{\"on\":false,\"bri\":254,\"hue\":53977,\"sat\":46,\"effect\":\"none\",\"xy\":[0.3756,0.3348],\"ct\":241,\"alert\":\"none\",\"colormode\":\"xy\",\"mode\":\"homeautomation\",\"reachable\":true},\"swupdate\":{\"state\":\"noupdates\",\"lastinstall\":\"2017-11-30T13:17:14\"},\"type\":\"Extended color light\",\"name\":\"E 1\",\"modelid\":\"LCT010\",\"manufacturername\":\"Philips\",\"capabilities\":{\"streaming\":{\"renderer\":true,\"proxy\":true}},\"uniqueid\":\"00:17:88:01:02:32:e6:ad-0b\",\"swversion\":\"1.29.0_r21169\",\"swconfigid\":\"6A139B19\",\"productid\":\"Philips-LCT010-1-A19ECLv4\"},\"12\":{\"state\":{\"on\":false,\"bri\":254,\"hue\":54346,\"sat\":25,\"effect\":\"none\",\"xy\":[0.3789,0.3545],\"ct\":244,\"alert\":\"none\",\"colormode\":\"xy\",\"mode\":\"homeautomation\",\"reachable\":true},\"swupdate\":{\"state\":\"noupdates\",\"lastinstall\":\"2017-11-30T13:17:09\"},\"type\":\"Extended color light\",\"name\":\"B 1\",\"modelid\":\"LCT010\",\"manufacturername\":\"Philips\",\"capabilities\":{\"streaming\":{\"renderer\":true,\"proxy\":true}},\"uniqueid\":\"00:17:88:01:02:34:da:4c-0b\",\"swversion\":\"1.29.0_r21169\",\"swconfigid\":\"6A139B19\",\"productid\":\"Philips-LCT010-1-A19ECLv4\"}}";

// read a file

char *readFile(const char *filename) {
    FILE *f = fopen(filename, "r");
    if (! f) return 0;
    assert(f);
    fseek(f, 0, SEEK_END);
    long length = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buffer = (char *) malloc(length + 1);
    buffer[length] = '\0';
    fread(buffer, 1, length, f);
    fclose(f);
    return buffer;
}

int my_printf(const char *str, int retcode, ...){
    char *buffer;
    va_list args, args1;
    va_start(args, retcode);
    va_copy(args1, args);
    size_t buffersize = vsnprintf(NULL,0 , str, args) + 1; // test buffersize
    va_end(args);
    buffer = malloc(buffersize);
    if (buffer == NULL) {
        Tcl_AppendStringsToObj(obj_str, "Failed to parse JSON, no memory allocation possible!\n", NULL);
        Tcl_SetObjResult(interpreter, obj_str);        
        return TCL_ERROR;
    }
    vsnprintf(buffer, buffersize, str, args1); // return the str
    va_end(args1);
    if (retcode == -2 ) { // fprintf
        Tcl_AppendStringsToObj(obj_str, buffer, NULL);
        retcode = TCL_ERROR;
    } else {
        Tcl_AppendStringsToObj(obj_str, buffer, NULL);
    }
     free(buffer);
    if (retcode > -1) {
        Tcl_SetObjResult(interpreter, obj_str);        
        return TCL_ERROR;
    } else {
        return TCL_OK;
    }
}

static inline void *realloc_it(void *ptrmem, size_t size) {
    void *p = realloc(ptrmem, size);
    if (!p)  {
        free (ptrmem);
        my_printf("realloc(): errno=%d\n", -2, errno);
    }
    return p;
}

void print_index(const char *js, int indent) {
    int i,j;
    if (indent == 0) return;
    my_printf("set %s(",-1, array_name);
    for (i = 1; i<=indent; i++) {
        int start = ar[2 * i - 2];
        int end = ar[2 * i - 1];
        if (i>1) {
            my_printf(",",-1);
        } else {
            for (j = 0; j < (places + start - end); j++) my_printf("0",-1); // fill 0 left
        }
        my_printf("%.*s", -1, end-start, js+start);
    }
    my_printf(") ", -1);
}
static int dump(const char *js, jsmntok_t *t, size_t count, int indent, int isTag) {
    int i, j;
    if (count == 0) {
        return 0;
    }
    if (t->type == JSMN_PRIMITIVE) {
        print_index(js, indent);
        if (indent > 0) my_printf("%.*s\n", -1, t->end - t->start, js+t->start);
        return 1;
    } else if (t->type == JSMN_STRING) {
        if (isTag) {
            ar[2 * indent - 2]= t->start;
            ar[2 * indent - 1]= t->end;
         } else {
            print_index(js, indent);
            if (indent > 0) my_printf("\"%.*s\"\n", -1, t->end - t->start, js+t->start);
        }
        return 1;
    } else if (t->type == JSMN_OBJECT) {
        j = 0;
        for (i = 0; i < t->size; i++) {
            // for (k = 0; k < indent; k++) printf("  ");
            j += dump(js, t+1+j, count-j, indent+1, 1);
            j += dump(js, t+1+j, count-j, indent+1, 0);
        }
        return j+1;
    } else if (t->type == JSMN_ARRAY) {
        j = 0;
        print_index(js, indent);
        int m1,m2;
        char *s ="";
        char *s1 ="";
        m1 = 0; m2 = 0;
        if (removebrackets) {
            m1 = 2; m2 = 1; s="{"; s1="}";
        }
        my_printf("%s%.*s%s\n", -1, s, t->end - t->start - m1, js+t->start + m2, s1);
       for (i = 0; i < t->size; i++) {
            // for (k = 0; k < indent-1; k++) my_printf("  ",-1);
            // my_printf("   - ", -1);
            j += dump(js, t+1+j, count-j, 0,0);
        }
        return j+1;
    }
    return 0;
}

int parse_json(const char* ar_name, const char * jsonstr) {
    int r;
    int eof_expected = 0;
    array_name = ar_name;
    JSON_STRING = jsonstr;
    ar = (int *)calloc(1024, sizeof(int));
    jsmn_parser p;
    jsmn_init(&p);
    jsmntok_t *tok;
    size_t tokcount = 200;
    tok = malloc(sizeof(*tok) * tokcount);
    if (tok == NULL) {
        return my_printf("Failed to parse JSON, no memory allocation possible!\n",3);
    }

    r = jsmn_parse(&p, JSON_STRING, strlen(JSON_STRING), tok, tokcount);
    while (r < 1) {
         switch(r) {
            case  0:
                return my_printf("No string to parse JSON.\n",0);
                break;
            case JSMN_ERROR_NOMEM:
                tokcount = tokcount * 2;
                tok = realloc_it(tok, sizeof(*tok) * tokcount);
                if (tok == NULL) {
                    return my_printf("Failed to parse JSON, no memory allocation possible!\n",3);
                }
                break;
            case JSMN_ERROR_INVAL:
                return my_printf("Failed to parse JSON, bad token, JSON string is corrupted!\n",2);
                 break;
            case JSMN_ERROR_PART:
                return my_printf("Failed to parse JSON, JSON string is too short, expecting more JSON data!\n",4);
                break;
             default:
                return my_printf("Failed to parse JSON: %d\n", 1, r);
                break;
        }
        r = jsmn_parse(&p, JSON_STRING, strlen(JSON_STRING), tok, tokcount);
     }
    dump(JSON_STRING, tok, p.toknext, 0, 0);
    eof_expected = 1;
    return EXIT_SUCCESS;
}


static int Json_Cmd(ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
  char *errormsg = "Error! Not enough arguments.\nSyntax: jsonparser arrayname jsonstring|file";
  int retval;
  /* Check if there is enough arguments to proceed with the function. */

  if (objc < 3) {


    obj_str = Tcl_NewStringObj(errormsg, strlen(errormsg));
    retval = TCL_ERROR;
  }   else {

    /* Concatenates the result string using the first argument. */

    obj_str = Tcl_NewStringObj("", -1);
    char* s = Tcl_GetStringFromObj(objv[1], NULL);
    char* t = Tcl_GetStringFromObj(objv[2], NULL);
    char* filestr;
    filestr = readFile(t);
    if (filestr ) {
        t = filestr;
    }
    if (objc == 4) {
        char* p = Tcl_GetStringFromObj(objv[3], NULL);
        places = strtol(p, NULL, 10);
    }
    if (objc == 5) {
        char* q = Tcl_GetStringFromObj(objv[4], NULL);
        removebrackets = strtol(q, NULL, 10);
    }
    interpreter = interp;
    retval = parse_json (s,t);
   }
  Tcl_SetObjResult(interp, obj_str);
  return retval;
}
static int List_Colors(ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
    int retval;
    Tcl_Obj *objStr;
    char *errormsg = "Error! too many arguments.\nSyntax: listColors  ?start_of_color_name?";
    /* Check if there is enough arguments to proceed with the function. */

 
    /* Concatenates the result string using the first argument. */

    if (objc > 2) {
        objStr = Tcl_NewStringObj(errormsg, strlen(errormsg));
        Tcl_SetObjResult(interp, objStr);
        return TCL_ERROR;
    }
    objStr = Tcl_NewStringObj("", -1);
    char *s;
    if (objc == 2) {
        s = Tcl_GetStringFromObj(objv[1], NULL);
    } else {
        s = "";
    }
    const char *ret = listColors(s);
    Tcl_AppendStringsToObj(objStr, ret, NULL);
    retval = TCL_OK;
   
  Tcl_SetObjResult(interp, objStr);
  return retval;
}

static int real_XY(ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
    int retval;
    Tcl_Obj *objStr;
    char *errormsg = "Error! Only two arguments.\nSyntax: realXY model XY";
    /* Check if there is enough arguments to proceed with the function. */

 
    /* Concatenates the result string using the first argument. */

    if (objc != 3) {
        objStr = Tcl_NewStringObj(errormsg, strlen(errormsg));
        Tcl_SetObjResult(interp, objStr);
        return TCL_ERROR;
    }
    objStr = Tcl_NewStringObj("", -1);
    char *model =Tcl_GetStringFromObj(objv[1], NULL);
    char *xy =Tcl_GetStringFromObj(objv[2], NULL);
    const char *ret = realXY(model, xy);
    Tcl_AppendStringsToObj(objStr, ret, NULL);
    retval = TCL_OK;
   
  Tcl_SetObjResult(interp, objStr);
  return retval;
}

static int gamut_ForModel(ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
    int retval;
    Tcl_Obj *objStr;
    char *errormsg = "Error! Only one argument.\nSyntax: gamutForModel model";
    /* Check if there is enough arguments to proceed with the function. */

 
    /* Concatenates the result string using the first argument. */

    if (objc != 2) {
        objStr = Tcl_NewStringObj(errormsg, strlen(errormsg));
        Tcl_SetObjResult(interp, objStr);
        return TCL_ERROR;
    }
    objStr = Tcl_NewStringObj("", -1);
    char *s;
    s = Tcl_GetStringFromObj(objv[1], NULL);
    const char *ret = gamutForModel(s);
    Tcl_AppendStringsToObj(objStr, ret, NULL);
    retval = TCL_OK;
   
  Tcl_SetObjResult(interp, objStr);
  return retval;
}

static int calc_RGB(ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
    int retval;
    Tcl_Obj *objStr;
    char *errormsg = "Error! Only two arguments.\nSyntax: calcRGB model XY";
    /* Check if there is enough arguments to proceed with the function. */

 
    /* Concatenates the result string using the first argument. */

    if (objc != 3) {
        objStr = Tcl_NewStringObj(errormsg, strlen(errormsg));
        Tcl_SetObjResult(interp, objStr);
        return TCL_ERROR;
    }
    objStr = Tcl_NewStringObj("", -1);
    char *model =Tcl_GetStringFromObj(objv[1], NULL);
    char *xy =Tcl_GetStringFromObj(objv[2], NULL);
    const char *ret = calcRGB(model, xy);
    Tcl_AppendStringsToObj(objStr, ret, NULL);
    retval = TCL_OK;
   
  Tcl_SetObjResult(interp, objStr);
  return retval;
}
static int real_RGB(ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
    int retval;
    Tcl_Obj *objStr;
    char *errormsg = "Error! Only one argument.\nSyntax: realGB rgb";
    /* Check if there is enough arguments to proceed with the function. */

 
    /* Concatenates the result string using the first argument. */

    if (objc != 2) {
        objStr = Tcl_NewStringObj(errormsg, strlen(errormsg));
        Tcl_SetObjResult(interp, objStr);
        return TCL_ERROR;
    }
    objStr = Tcl_NewStringObj("", -1);
    char *rgb =Tcl_GetStringFromObj(objv[1], NULL);
    const char *ret = realRGB(rgb);
    Tcl_AppendStringsToObj(objStr, ret, NULL);
    retval = TCL_OK;
   
  Tcl_SetObjResult(interp, objStr);
  return retval;
}


static int calc_XY(ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
    int retval;
    Tcl_Obj *objStr;
    char *errormsg = "Error! Only two arguments.\nSyntax: calcXY  model RGB";
    /* Check if there is enough arguments to proceed with the function. */

 
    /* Concatenates the result string using the first argument. */

    if (objc != 3) {
        objStr = Tcl_NewStringObj(errormsg, strlen(errormsg));
        Tcl_SetObjResult(interp, objStr);
        return TCL_ERROR;
    }
    objStr = Tcl_NewStringObj("", -1);
    char *model =Tcl_GetStringFromObj(objv[1], NULL);
    char *rgb =Tcl_GetStringFromObj(objv[2], NULL);
    const char *ret = calcXY(model, rgb);
    Tcl_AppendStringsToObj(objStr, ret, NULL);
    retval = TCL_OK;
   
  Tcl_SetObjResult(interp, objStr);
  return retval;
}

/*
* Json_Init -- Called when Tcl loads your extension.
*/
int DLLEXPORT Tools_Init(Tcl_Interp *interp) {
  if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL) {
    return TCL_ERROR;
  }
  /* changed this to check for an error - GPS */
  if (Tcl_PkgProvide(interp, "Jsonparser", "1.0") == TCL_ERROR) {
    return TCL_ERROR;
  }
  Tcl_CreateObjCommand(interp, "jsonparser", Json_Cmd, NULL, NULL);
  Tcl_CreateObjCommand(interp, "listColors", List_Colors, NULL, NULL);
  Tcl_CreateObjCommand(interp, "calcXY", calc_XY, NULL, NULL);
  Tcl_CreateObjCommand(interp, "calcRGB", calc_RGB, NULL, NULL);
  Tcl_CreateObjCommand(interp, "realRGB", real_RGB, NULL, NULL);
  Tcl_CreateObjCommand(interp, "gamutForModel", gamut_ForModel, NULL, NULL);
  Tcl_CreateObjCommand(interp, "realXY", real_XY, NULL, NULL);
  return TCL_OK;
}

int main() {
  return 0;
}
