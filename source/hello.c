#include <string.h>  /* strlen() */
#include <tcl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <errno.h>
#include <assert.h>
#include "color.h"

Tcl_Obj *obj_str;
Tcl_Interp *interpreter;

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

    if (objc != 9) {
        objStr = Tcl_NewStringObj(errormsg, strlen(errormsg));
        Tcl_SetObjResult(interp, objStr);
        return TCL_ERROR;
    }
    objStr = Tcl_NewStringObj("", -1);
    float x = atof(Tcl_GetStringFromObj(objv[1], NULL));
    float y = atof(Tcl_GetStringFromObj(objv[2], NULL));
    float redX = atof(Tcl_GetStringFromObj(objv[3], NULL));
    float redY = atof(Tcl_GetStringFromObj(objv[4], NULL));
    float greenX = atof(Tcl_GetStringFromObj(objv[5], NULL));
    float greenY = atof(Tcl_GetStringFromObj(objv[6], NULL));
    float blueX = atof(Tcl_GetStringFromObj(objv[7], NULL));
    float blueY = atof(Tcl_GetStringFromObj(objv[8], NULL));
    const char *ret = realXY(x, y, redX, redY, greenX, greenY, blueX, blueY);
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

    if (objc != 9) {
        objStr = Tcl_NewStringObj(errormsg, strlen(errormsg));
        Tcl_SetObjResult(interp, objStr);
        return TCL_ERROR;
    }
    objStr = Tcl_NewStringObj("", -1);
    float x = atof(Tcl_GetStringFromObj(objv[1], NULL));
    float y = atof(Tcl_GetStringFromObj(objv[2], NULL));
    float redX = atof(Tcl_GetStringFromObj(objv[3], NULL));
    float redY = atof(Tcl_GetStringFromObj(objv[4], NULL));
    float greenX = atof(Tcl_GetStringFromObj(objv[5], NULL));
    float greenY = atof(Tcl_GetStringFromObj(objv[6], NULL));
    float blueX = atof(Tcl_GetStringFromObj(objv[7], NULL));
    float blueY = atof(Tcl_GetStringFromObj(objv[8], NULL));
    const char *ret = calcRGB(x, y, redX, redY, greenX, greenY, blueX, blueY);
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

    if (objc != 8) {
        objStr = Tcl_NewStringObj(errormsg, strlen(errormsg));
        Tcl_SetObjResult(interp, objStr);
        return TCL_ERROR;
    }
    objStr = Tcl_NewStringObj("", -1);
    char *rgb =Tcl_GetStringFromObj(objv[1], NULL);
    float redX = atof(Tcl_GetStringFromObj(objv[2], NULL));
    float redY = atof(Tcl_GetStringFromObj(objv[3], NULL));
    float greenX = atof(Tcl_GetStringFromObj(objv[4], NULL));
    float greenY = atof(Tcl_GetStringFromObj(objv[5], NULL));
    float blueX = atof(Tcl_GetStringFromObj(objv[6], NULL));
    float blueY = atof(Tcl_GetStringFromObj(objv[7], NULL));
    const char *ret = calcXY(rgb, redX, redY, greenX, greenY, blueX, blueY);
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
  if (Tcl_PkgProvide(interp, "Color", "2.0") == TCL_ERROR) {
    return TCL_ERROR;
  }
  Tcl_CreateObjCommand(interp, "listColors", List_Colors, NULL, NULL);
  Tcl_CreateObjCommand(interp, "calcXY", calc_XY, NULL, NULL);
  Tcl_CreateObjCommand(interp, "calcRGB", calc_RGB, NULL, NULL);
  Tcl_CreateObjCommand(interp, "realRGB", real_RGB, NULL, NULL);
  Tcl_CreateObjCommand(interp, "realXY", real_XY, NULL, NULL);
  return TCL_OK;
}

int main() {
  return 0;
}
