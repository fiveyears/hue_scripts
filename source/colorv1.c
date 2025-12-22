#include "colorv1.h"
#include "math.h"
#include "string.h"
#include "stdio.h"
#include "stdlib.h"

#define colorcount 654

const char  *colornames [colorcount] = {"black","AliceBlue","BlueViolet","CadetBlue","CadetBlue1","CadetBlue2","CadetBlue3","CadetBlue4","CornflowerBlue","DarkBlue","DarkCyan","DarkSlateBlue","DarkTurquoise","DeepSkyBlue","DeepSkyBlue1","DeepSkyBlue2","DeepSkyBlue3","DeepSkyBlue4","DodgerBlue","DodgerBlue1","DodgerBlue2","DodgerBlue3","DodgerBlue4","LightBlue","LightBlue1","LightBlue2","LightBlue3","LightBlue4","LightCyan","LightCyan1","LightCyan2","LightCyan3","LightCyan4","LightSkyBlue","LightSkyBlue1","LightSkyBlue2","LightSkyBlue3","LightSkyBlue4","LightSlateBlue","LightSteelBlue","LightSteelBlue1","LightSteelBlue2","LightSteelBlue3","LightSteelBlue4","MediumAquamarine","MediumBlue","MediumSlateBlue","MediumTurquoise","MidnightBlue","NavyBlue","PaleTurquoise","PaleTurquoise1","PaleTurquoise2","PaleTurquoise3","PaleTurquoise4","PowderBlue","RoyalBlue","RoyalBlue1","RoyalBlue2","RoyalBlue3","RoyalBlue4","SkyBlue","SkyBlue1","SkyBlue2","SkyBlue3","SkyBlue4","SlateBlue","SlateBlue1","SlateBlue2","SlateBlue3","SlateBlue4","SteelBlue","SteelBlue1","SteelBlue2","SteelBlue3","SteelBlue4","aquamarine","aquamarine1","aquamarine2","aquamarine3","aquamarine4","azure","azure1","azure2","azure3","azure4","blue","blue1","blue2","blue3","blue4","cyan","cyan1","cyan2","cyan3","cyan4","navy","turquoise","turquoise1","turquoise2","turquoise3","turquoise4","RosyBrown","RosyBrown1","RosyBrown2","RosyBrown3","RosyBrown4","SaddleBrown","SandyBrown","beige","brown","brown1","brown2","brown3","brown4","burlywood","burlywood1","burlywood2","burlywood3","burlywood4","chocolate","chocolate1","chocolate2","chocolate3","chocolate4","peru","tan","tan1","tan2","tan3","tan4","DarkSlateGray","DarkSlateGray1","DarkSlateGray2","DarkSlateGray3","DarkSlateGray4","DarkSlateGrey","DimGray","DimGrey","LightGray","LightGrey","LightSlateGray","SlateGray","SlateGray1","SlateGray2","SlateGray3","SlateGray4","SlateGrey","gray","gray0","gray1","gray2","gray3","gray4","gray5","gray6","gray7","gray8","gray9","gray10","gray11","gray12","gray13","gray14","gray15","gray16","gray17","gray18","gray19","gray20","gray21","gray22","gray23","gray24","gray25","gray26","gray27","gray28","gray29","gray30","gray31","gray32","gray33","gray34","gray35","gray36","gray37","gray38","gray39","gray40","gray41","gray42","gray43","gray44","gray45","gray46","gray47","gray48","gray49","gray50","gray51","gray52","gray53","gray54","gray55","gray56","gray57","gray58","gray59","gray60","gray61","gray62","gray63","gray64","gray65","gray66","gray67","gray68","gray69","gray70","gray71","gray72","gray73","gray74","gray75","gray76","gray77","gray78","gray79","gray80","gray81","gray82","gray83","gray84","gray85","gray86","gray87","gray88","gray89","gray90","gray91","gray92","gray93","gray94","gray95","gray96","gray97","gray98","gray99","gray100","grey","grey0","grey1","grey2","grey3","grey4","grey5","grey6","grey7","grey8","grey9","grey10","grey11","grey12","grey13","grey14","grey15","grey16","grey17","grey18","grey19","grey20","grey21","grey22","grey23","grey24","grey25","grey26","grey27","grey28","grey29","grey30","grey31","grey32","grey33","grey34","grey35","grey36","grey37","grey38","grey39","grey40","grey41","grey42","grey43","grey44","grey45","grey46","grey47","grey48","grey49","grey50","grey51","grey52","grey53","grey54","grey55","grey56","grey57","grey58","grey59","grey60","grey61","grey62","grey63","grey64","grey65","grey66","grey67","grey68","grey69","grey70","grey71","grey72","grey73","grey74","grey75","grey76","grey77","grey78","grey79","grey80","grey81","grey82","grey83","grey84","grey85","grey86","grey87","grey88","grey89","grey90","grey91","grey92","grey93","grey94","grey95","grey96","grey97","grey98","grey99","grey100","DarkGreen","DarkKhaki","DarkOliveGreen","DarkOliveGreen1","DarkOliveGreen2","DarkOliveGreen3","DarkOliveGreen4","DarkSeaGreen","DarkSeaGreen1","DarkSeaGreen2","DarkSeaGreen3","DarkSeaGreen4","ForestGreen","GreenYellow","LawnGreen","LightGreen","LightSeaGreen","LimeGreen","MediumSeaGreen","MediumSpringGreen","MintCream","OliveDrab","OliveDrab1","OliveDrab2","OliveDrab3","OliveDrab4","PaleGreen","PaleGreen1","PaleGreen2","PaleGreen3","PaleGreen4","SeaGreen","SeaGreen1","SeaGreen2","SeaGreen3","SeaGreen4","SpringGreen","SpringGreen1","SpringGreen2","SpringGreen3","SpringGreen4","YellowGreen","chartreuse","chartreuse1","chartreuse2","chartreuse3","chartreuse4","green","green1","green2","green3","green4","khaki","khaki1","khaki2","khaki3","khaki4","DarkOrange","DarkOrange1","DarkOrange2","DarkOrange3","DarkOrange4","DarkSalmon","LightCoral","LightSalmon","LightSalmon1","LightSalmon2","LightSalmon3","LightSalmon4","PeachPuff","PeachPuff1","PeachPuff2","PeachPuff3","PeachPuff4","bisque","bisque1","bisque2","bisque3","bisque4","coral","coral1","coral2","coral3","coral4","honeydew","honeydew1","honeydew2","honeydew3","honeydew4","orange","orange1","orange2","orange3","orange4","salmon","salmon1","salmon2","salmon3","salmon4","sienna","sienna1","sienna2","sienna3","sienna4","DarkRed","DeepPink","DeepPink1","DeepPink2","DeepPink3","DeepPink4","HotPink","HotPink1","HotPink2","HotPink3","HotPink4","IndianRed","IndianRed1","IndianRed2","IndianRed3","IndianRed4","LightPink","LightPink1","LightPink2","LightPink3","LightPink4","MediumVioletRed","MistyRose","MistyRose1","MistyRose2","MistyRose3","MistyRose4","OrangeRed","OrangeRed1","OrangeRed2","OrangeRed3","OrangeRed4","PaleVioletRed","PaleVioletRed1","PaleVioletRed2","PaleVioletRed3","PaleVioletRed4","VioletRed","VioletRed1","VioletRed2","VioletRed3","VioletRed4","firebrick","firebrick1","firebrick2","firebrick3","firebrick4","pink","pink1","pink2","pink3","pink4","red","red1","red2","red3","red4","tomato","tomato1","tomato2","tomato3","tomato4","DarkMagenta","DarkOrchid","DarkOrchid1","DarkOrchid2","DarkOrchid3","DarkOrchid4","DarkViolet","LavenderBlush","LavenderBlush1","LavenderBlush2","LavenderBlush3","LavenderBlush4","MediumOrchid","MediumOrchid1","MediumOrchid2","MediumOrchid3","MediumOrchid4","MediumPurple","MediumPurple1","MediumPurple2","MediumPurple3","MediumPurple4","lavender","magenta","magenta1","magenta2","magenta3","magenta4","maroon","maroon1","maroon2","maroon3","maroon4","orchid","orchid1","orchid2","orchid3","orchid4","plum","plum1","plum2","plum3","plum4","purple","purple1","purple2","purple3","purple4","thistle","thistle1","thistle2","thistle3","thistle4","violet","AntiqueWhite","AntiqueWhite1","AntiqueWhite2","AntiqueWhite3","AntiqueWhite4","FloralWhite","GhostWhite","NavajoWhite","NavajoWhite1","NavajoWhite2","NavajoWhite3","NavajoWhite4","OldLace","WhiteSmoke","gainsboro","ivory","ivory1","ivory2","ivory3","ivory4","linen","seashell","seashell1","seashell2","seashell3","seashell4","snow","snow1","snow2","snow3","snow4","wheat","wheat1","wheat2","wheat3","wheat4","white","BlanchedAlmond","DarkGoldenrod","DarkGoldenrod1","DarkGoldenrod2","DarkGoldenrod3","DarkGoldenrod4","LemonChiffon","LemonChiffon1","LemonChiffon2","LemonChiffon3","LemonChiffon4","LightGoldenrod","LightGoldenrod1","LightGoldenrod2","LightGoldenrod3","LightGoldenrod4","LightGoldenrodYellow","LightYellow","LightYellow1","LightYellow2","LightYellow3","LightYellow4","PaleGoldenrod","PapayaWhip","cornsilk","cornsilk1","cornsilk2","cornsilk3","cornsilk4","gold","gold1","gold2","gold3","gold4","goldenrod","goldenrod1","goldenrod2","goldenrod3","goldenrod4","moccasin","yellow","yellow1","yellow2","yellow3","yellow4"};
const char  *colorsrgb [colorcount] = {"000000", "F0F8FF", "8A2BE2", "5F9EA0", "98F5FF", "8EE5EE", "7AC5CD", "53868B", "6495ED", "00008B", "008B8B", "483D8B", "00CED1", "00BFFF", "00BFFF", "00B2EE", "009ACD", "00688B", "1E90FF", "1E90FF", "1C86EE", "1874CD", "104E8B", "ADD8E6", "BFEFFF", "B2DFEE", "9AC0CD", "68838B", "E0FFFF", "E0FFFF", "D1EEEE", "B4CDCD", "7A8B8B", "87CEFA", "B0E2FF", "A4D3EE", "8DB6CD", "607B8B", "8470FF", "B0C4DE", "CAE1FF", "BCD2EE", "A2B5CD", "6E7B8B", "66CDAA", "0000CD", "7B68EE", "48D1CC", "191970", "000080", "AFEEEE", "BBFFFF", "AEEEEE", "96CDCD", "668B8B", "B0E0E6", "4169E1", "4876FF", "436EEE", "3A5FCD", "27408B", "87CEEB", "87CEFF", "7EC0EE", "6CA6CD", "4A708B", "6A5ACD", "836FFF", "7A67EE", "6959CD", "473C8B", "4682B4", "63B8FF", "5CACEE", "4F94CD", "36648B", "7FFFD4", "7FFFD4", "76EEC6", "66CDAA", "458B74", "F0FFFF", "F0FFFF", "E0EEEE", "C1CDCD", "838B8B", "0000FF", "0000FF", "0000EE", "0000CD", "00008B", "00FFFF", "00FFFF", "00EEEE", "00CDCD", "008B8B", "000080", "40E0D0", "00F5FF", "00E5EE", "00C5CD", "00868B", "BC8F8F", "FFC1C1", "EEB4B4", "CD9B9B", "8B6969", "8B4513", "F4A460", "F5F5DC", "A52A2A", "FF4040", "EE3B3B", "CD3333", "8B2323", "DEB887", "FFD39B", "EEC591", "CDAA7D", "8B7355", "D2691E", "FF7F24", "EE7621", "CD661D", "8B4513", "CD853F", "D2B48C", "FFA54F", "EE9A49", "CD853F", "8B5A2B", "2F4F4F", "97FFFF", "8DEEEE", "79CDCD", "528B8B", "2F4F4F", "696969", "696969", "D3D3D3", "D3D3D3", "778899", "708090", "C6E2FF", "B9D3EE", "9FB6CD", "6C7B8B", "708090", "BEBEBE", "000000", "030303", "050505", "080808", "0A0A0A", "0D0D0D", "0F0F0F", "121212", "141414", "171717", "1A1A1A", "1C1C1C", "1F1F1F", "212121", "242424", "262626", "292929", "2B2B2B", "2E2E2E", "303030", "333333", "363636", "383838", "3B3B3B", "3D3D3D", "404040", "424242", "454545", "474747", "4A4A4A", "4D4D4D", "4F4F4F", "525252", "545454", "575757", "595959", "5C5C5C", "5E5E5E", "616161", "636363", "666666", "696969", "6B6B6B", "6E6E6E", "707070", "737373", "757575", "787878", "7A7A7A", "7D7D7D", "7F7F7F", "828282", "858585", "878787", "8A8A8A", "8C8C8C", "8F8F8F", "919191", "949494", "969696", "999999", "9C9C9C", "9E9E9E", "A1A1A1", "A3A3A3", "A6A6A6", "A8A8A8", "ABABAB", "ADADAD", "B0B0B0", "B3B3B3", "B5B5B5", "B8B8B8", "BABABA", "BDBDBD", "BFBFBF", "C2C2C2", "C4C4C4", "C7C7C7", "C9C9C9", "CCCCCC", "CFCFCF", "D1D1D1", "D4D4D4", "D6D6D6", "D9D9D9", "DBDBDB", "DEDEDE", "E0E0E0", "E3E3E3", "E5E5E5", "E8E8E8", "EBEBEB", "EDEDED", "F0F0F0", "F2F2F2", "F5F5F5", "F7F7F7", "FAFAFA", "FCFCFC", "FFFFFF", "BEBEBE", "000000", "030303", "050505", "080808", "0A0A0A", "0D0D0D", "0F0F0F", "121212", "141414", "171717", "1A1A1A", "1C1C1C", "1F1F1F", "212121", "242424", "262626", "292929", "2B2B2B", "2E2E2E", "303030", "333333", "363636", "383838", "3B3B3B", "3D3D3D", "404040", "424242", "454545", "474747", "4A4A4A", "4D4D4D", "4F4F4F", "525252", "545454", "575757", "595959", "5C5C5C", "5E5E5E", "616161", "636363", "666666", "696969", "6B6B6B", "6E6E6E", "707070", "737373", "757575", "787878", "7A7A7A", "7D7D7D", "7F7F7F", "828282", "858585", "878787", "8A8A8A", "8C8C8C", "8F8F8F", "919191", "949494", "969696", "999999", "9C9C9C", "9E9E9E", "A1A1A1", "A3A3A3", "A6A6A6", "A8A8A8", "ABABAB", "ADADAD", "B0B0B0", "B3B3B3", "B5B5B5", "B8B8B8", "BABABA", "BDBDBD", "BFBFBF", "C2C2C2", "C4C4C4", "C7C7C7", "C9C9C9", "CCCCCC", "CFCFCF", "D1D1D1", "D4D4D4", "D6D6D6", "D9D9D9", "DBDBDB", "DEDEDE", "E0E0E0", "E3E3E3", "E5E5E5", "E8E8E8", "EBEBEB", "EDEDED", "F0F0F0", "F2F2F2", "F5F5F5", "F7F7F7", "FAFAFA", "FCFCFC", "FFFFFF", "006400", "BDB76B", "556B2F", "CAFF70", "BCEE68", "A2CD5A", "6E8B3D", "8FBC8F", "C1FFC1", "B4EEB4", "9BCD9B", "698B69", "228B22", "ADFF2F", "7CFC00", "90EE90", "20B2AA", "32CD32", "3CB371", "00FA9A", "F5FFFA", "6B8E23", "C0FF3E", "B3EE3A", "9ACD32", "698B22", "98FB98", "9AFF9A", "90EE90", "7CCD7C", "548B54", "2E8B57", "54FF9F", "4EEE94", "43CD80", "2E8B57", "00FF7F", "00FF7F", "00EE76", "00CD66", "008B45", "9ACD32", "7FFF00", "7FFF00", "76EE00", "66CD00", "458B00", "00FF00", "00FF00", "00EE00", "00CD00", "008B00", "F0E68C", "FFF68F", "EEE685", "CDC673", "8B864E", "FF8C00", "FF7F00", "EE7600", "CD6600", "8B4500", "E9967A", "F08080", "FFA07A", "FFA07A", "EE9572", "CD8162", "8B5742", "FFDAB9", "FFDAB9", "EECBAD", "CDAF95", "8B7765", "FFE4C4", "FFE4C4", "EED5B7", "CDB79E", "8B7D6B", "FF7F50", "FF7256", "EE6A50", "CD5B45", "8B3E2F", "F0FFF0", "F0FFF0", "E0EEE0", "C1CDC1", "838B83", "FFA500", "FFA500", "EE9A00", "CD8500", "8B5A00", "FA8072", "FF8C69", "EE8262", "CD7054", "8B4C39", "A0522D", "FF8247", "EE7942", "CD6839", "8B4726", "8B0000", "FF1493", "FF1493", "EE1289", "CD1076", "8B0A50", "FF69B4", "FF6EB4", "EE6AA7", "CD6090", "8B3A62", "CD5C5C", "FF6A6A", "EE6363", "CD5555", "8B3A3A", "FFB6C1", "FFAEB9", "EEA2AD", "CD8C95", "8B5F65", "C71585", "FFE4E1", "FFE4E1", "EED5D2", "CDB7B5", "8B7D7B", "FF4500", "FF4500", "EE4000", "CD3700", "8B2500", "DB7093", "FF82AB", "EE799F", "CD6889", "8B475D", "D02090", "FF3E96", "EE3A8C", "CD3278", "8B2252", "B22222", "FF3030", "EE2C2C", "CD2626", "8B1A1A", "FFC0CB", "FFB5C5", "EEA9B8", "CD919E", "8B636C", "FF0000", "FF0000", "EE0000", "CD0000", "8B0000", "FF6347", "FF6347", "EE5C42", "CD4F39", "8B3626", "8B008B", "9932CC", "BF3EFF", "B23AEE", "9A32CD", "68228B", "9400D3", "FFF0F5", "FFF0F5", "EEE0E5", "CDC1C5", "8B8386", "BA55D3", "E066FF", "D15FEE", "B452CD", "7A378B", "9370DB", "AB82FF", "9F79EE", "8968CD", "5D478B", "E6E6FA", "FF00FF", "FF00FF", "EE00EE", "CD00CD", "8B008B", "B03060", "FF34B3", "EE30A7", "CD2990", "8B1C62", "DA70D6", "FF83FA", "EE7AE9", "CD69C9", "8B4789", "DDA0DD", "FFBBFF", "EEAEEE", "CD96CD", "8B668B", "A020F0", "9B30FF", "912CEE", "7D26CD", "551A8B", "D8BFD8", "FFE1FF", "EED2EE", "CDB5CD", "8B7B8B", "EE82EE", "FAEBD7", "FFEFDB", "EEDFCC", "CDC0B0", "8B8378", "FFFAF0", "F8F8FF", "FFDEAD", "FFDEAD", "EECFA1", "CDB38B", "8B795E", "FDF5E6", "F5F5F5", "DCDCDC", "FFFFF0", "FFFFF0", "EEEEE0", "CDCDC1", "8B8B83", "FAF0E6", "FFF5EE", "FFF5EE", "EEE5DE", "CDC5BF", "8B8682", "FFFAFA", "FFFAFA", "EEE9E9", "CDC9C9", "8B8989", "F5DEB3", "FFE7BA", "EED8AE", "CDBA96", "8B7E66", "FFFFFF", "FFEBCD", "B8860B", "FFB90F", "EEAD0E", "CD950C", "8B6508", "FFFACD", "FFFACD", "EEE9BF", "CDC9A5", "8B8970", "EEDD82", "FFEC8B", "EEDC82", "CDBE70", "8B814C", "FAFAD2", "FFFFE0", "FFFFE0", "EEEED1", "CDCDB4", "8B8B7A", "EEE8AA", "FFEFD5", "FFF8DC", "FFF8DC", "EEE8CD", "CDC8B1", "8B8878", "FFD700", "FFD700", "EEC900", "CDAD00", "8B7500", "DAA520", "FFC125", "EEB422", "CD9B1D", "8B6914", "FFE4B5", "FFFF00", "FFFF00", "EEEE00", "CDCD00", "8B8B00"};
    
CGPoint CGPointMake(float x, float y);
CGPoint _realXY  (CGPoint xy, const char *model) ;
float crossProduct(CGPoint p1,  CGPoint p2);
CGPoint getClosestPointToPoints(CGPoint A, CGPoint B, CGPoint P);
float getDistanceBetweenTwoPoints(CGPoint one, CGPoint two);
int checkPointInLampsReach(CGPoint p,  ColorPoints colorPoints);
Color colorFromXY (CGPoint xy, const char *model);
CGPoint calculateXY (Color color, const char* model);
ColorPoints colorPointsForModel (const char* model);
const char* join_strings(char* strings[], char* seperator, int count);

const char* join_strings(char* strings[], char* seperator, int count) {
    char* str = NULL;             /* Pointer to the joined strings  */
    size_t total_length = 0;      /* Total length of joined strings */
    int i = 0;                    /* Loop counter                   */

    /* Find total length of joined strings */
    for (i = 0; i < count; i++) total_length += strlen(strings[i]);
    total_length++;     /* For joined string terminator */
    total_length += strlen(seperator) * (count - 1); // for seperators

    str = malloc(total_length);  /* Allocate memory for joined strings */
    str[0] = '\0';                      /* Empty string we can append to      */

    /* Append all the strings */
    for (i = 0; i < count; i++) {
        strcat(str, strings[i]);
        if (i < (count - 1)) strcat(str, seperator);
    }

    return str;
}
CGPoint CGPointMake(float x, float y)
{
    CGPoint p; p.x = x; p.y = y; return p;
}

const char* gamutForModel (const char* model) {
    const char * GamutA =   "LLC001," /* Monet, Renoir, Mondriaan (gen II) */
                            "LLC005," /* Bloom (gen II) */
                            "LLC006," /* Iris (gen III) */
                            "LLC007," /* Bloom, Aura (gen III) */
                            "LLC011," /* Hue Bloom */
                            "LLC012," /* Hue Bloom */
                            "LLC013," /* Storylight */
                            "LST001"; /* Light Strips */
    const char * GamutB =   "LCT001," /* Hue A19 */
                            "LCT002," /* Hue BR30 */
                            "LCT003"; /* Hue GU10 */
    const char * GamutC =   "LCT010," /* Hue A19 */
                            "LCT011," /* Hue BR30 Richer Colors */
                            "LCT014," /* Hue A19 */
                            "LCT015," /* Hue A19 */
                            "LCT016," /* Hue A19 */
                            "LLC020," /* Hue Go */
                            "LCT012," /* Hue color candle */
                            "LST002"; /* Light Strips plus*/

    char *gamutA = strstr(GamutA, model);
    char *gamutB = strstr(GamutB, model);
    char *gamutC = strstr(GamutC, model);
    if (gamutA) { //Gamut A
        return "A";
            
    }
    else if(gamutB) // Gammut B
    {
        return "B";
    }
    else if (gamutC) { //Gamut C
        return "C";
    }
    else {
        return "no";
    }
}

ColorPoints colorPointsForModel (const char* model) {
    ColorPoints colorPoints ;
    const char* gamut = gamutForModel(model);

   
    if (strcmp(gamut,"A")==0) { //Gamut A
        colorPoints.red.x =0.704F;
        colorPoints.red.y =0.296F;
        colorPoints.green.x =0.2151F;
        colorPoints.green.y =0.7106F;
        colorPoints.blue.x =0.138F;
        colorPoints.blue.y =0.08F;
            
    }
    else if(strcmp(gamut,"B")==0) // Gammut B
    {
        colorPoints.red.x =0.675F;
        colorPoints.red.y =0.322F;
        colorPoints.green.x =0.409F;
        colorPoints.green.y =0.518F;
        colorPoints.blue.x =0.167F;
        colorPoints.blue.y =0.04F;
    }
    else if (strcmp(gamut,"C")==0) { //Gamut C
        colorPoints.red.x =0.692;
        colorPoints.red.y =0.308F;
        colorPoints.green.x =0.17F;
        colorPoints.green.y =0.7F;
        colorPoints.blue.x =0.153F;
        colorPoints.blue.y =0.048F;
    }
    else {
        colorPoints.red.x =1.0F;
        colorPoints.red.y =0.0F;
        colorPoints.green.x =0.0F;
        colorPoints.green.y =1.0F;
        colorPoints.blue.x =0.0F;
        colorPoints.blue.y =0.0F;
    }
    
    return colorPoints;
}

float crossProduct(CGPoint p1,  CGPoint p2) {
    return (p1.x * p2.y - p1.y * p2.x);
}

CGPoint getClosestPointToPoints(CGPoint A, CGPoint B, CGPoint P) {
    CGPoint AP = CGPointMake(P.x - A.x, P.y - A.y);
    CGPoint AB = CGPointMake(B.x - A.x, B.y - A.y);
    float ab2 = AB.x * AB.x + AB.y * AB.y;
    float ap_ab = AP.x * AB.x + AP.y * AB.y;
    
    float t = ap_ab / ab2;
    
    if (t < 0.0f) {
        t = 0.0f;
    }
    else if (t > 1.0f) {
        t = 1.0f;
    }
    
    CGPoint newPoint = CGPointMake(A.x + AB.x * t, A.y + AB.y * t);
    return newPoint;
}

float getDistanceBetweenTwoPoints(CGPoint one, CGPoint two) {
    float dx = one.x - two.x; // horizontal difference
    float dy = one.y - two.y; // vertical difference
    float dist = sqrt(dx * dx + dy * dy);
    return dist;
}

int checkPointInLampsReach(CGPoint p,  ColorPoints colorPoints) {
    CGPoint red =   colorPoints.red;
    CGPoint green = colorPoints.green;
    CGPoint blue =  colorPoints.blue;
    
    CGPoint v1 = CGPointMake(green.x - red.x, green.y - red.y);
    CGPoint v2 = CGPointMake(blue.x - red.x, blue.y - red.y);
    
    CGPoint q = CGPointMake(p.x - red.x, p.y - red.y);
    
    float s = crossProduct (q, v2) / crossProduct (v1, v2);
    float t = crossProduct (v1, q) / crossProduct (v1, v2);
    
    if ( (s >= 0.0f) && (t >= 0.0f) && (s + t <= 1.0f)) {
        return 1;
    }
    else {
        return 0;
    }
}

const char * realXY (const char *XY, const char *model) {
    float x,y;
    int i = sscanf(XY, "%f,%f", &x,&y);
    if (i != 2) {
        return "Wrong xy-format, must be two floats";
    } 
    CGPoint xy = _realXY  (CGPointMake(x, y), model);
    static char ss1[14];
    snprintf(ss1, 14, "%.4f,%.4f\n", xy.x, xy.y);
    return ss1;

}

CGPoint _realXY  (CGPoint xy, const char *model) {
    ColorPoints colorPoints = colorPointsForModel (model);
    int inReachOfLamps = checkPointInLampsReach (xy, colorPoints);
    
    if (!inReachOfLamps) {
        //It seems the colour is out of reach
        //let's find the closest colour we can produce with our lamp and send this XY value out.
        
        //Find the closest point on each line in the triangle.
        CGPoint pAB =getClosestPointToPoints(colorPoints.red, colorPoints.green,xy);
        CGPoint pAC = getClosestPointToPoints(colorPoints.blue, colorPoints.red,xy);
        CGPoint pBC = getClosestPointToPoints(colorPoints.green, colorPoints.blue,xy);
        
        //Get the distances per point and see which point is closer to our Point.
        float dAB = getDistanceBetweenTwoPoints (xy,pAB);
        float dAC = getDistanceBetweenTwoPoints (xy,pAC);
        float dBC = getDistanceBetweenTwoPoints (xy,pBC);
        
        float lowest = dAB;
        CGPoint closestPoint = pAB;
        
        if (dAC < lowest) {
            lowest = dAC;
            closestPoint = pAC;
        }
        if (dBC < lowest) {
            lowest = dBC;
            closestPoint = pBC;
        }
        
        //Change the xy value to a value which is within the reach of the lamp.
        xy.x = closestPoint.x;
        xy.y = closestPoint.y;
    }
    return xy;

}

Color colorFromXY (CGPoint xy, const char *model) {
    xy = _realXY(xy, model);
    
    float x = xy.x;
    float y = xy.y;
    float z = 1.0f - x - y;
    
    float Y = 1.0f;
    float X = (Y / y) * x;
    float Z = (Y / y) * z;
    
    // sRGB D65 conversion
    float r =  X * 1.656492f - Y * 0.354851f - Z * 0.255038f;
    float g = -X * 0.707196f + Y * 1.655397f + Z * 0.036152f;
    float b =  X * 0.051713f - Y * 0.121364f + Z * 1.011530f;
    
    if (r > b && r > g && r > 1.0f) {
        // red is too big
        g = g / r;
        b = b / r;
        r = 1.0f;
    }
    else if (g > b && g > r && g > 1.0f) {
        // green is too big
        r = r / g;
        b = b / g;
        g = 1.0f;
    }
    else if (b > r && b > g && b > 1.0f) {
        // blue is too big
        r = r / b;
        g = g / b;
        b = 1.0f;
    }
    
    // Apply gamma correction
    r = r <= 0.0031308f ? 12.92f * r : (1.0f + 0.055f) * pow(r, (1.0f / 2.4f)) - 0.055f;
    g = g <= 0.0031308f ? 12.92f * g : (1.0f + 0.055f) * pow(g, (1.0f / 2.4f)) - 0.055f;
    b = b <= 0.0031308f ? 12.92f * b : (1.0f + 0.055f) * pow(b, (1.0f / 2.4f)) - 0.055f;
    
    if (r > b && r > g) {
        // red is biggest
        if (r > 1.0f) {
            g = g / r;
            b = b / r;
            r = 1.0f;
        }
    }
    else if (g > b && g > r) {
        // green is biggest
        if (g > 1.0f) {
            r = r / g;
            b = b / g;
            g = 1.0f;
        }
    }
    else if (b > r && b > g) {
        // blue is biggest
        if (b > 1.0f) {
            r = r / b;
            g = g / b;
            b = 1.0f;
        }
    }
    if (r < 0) r = 0;
    if (g < 0) g = 0;
    if (b < 0) b = 0;
    Color color;
    color.red= r; color.green = g; color.blue = b;
    return color;
}

CGPoint calculateXY (Color color, const char* model) {
    
    // Default to white
    float red = 1.0f;
    float green = 1.0f;
    float blue = 1.0f;
    
    red = color.red;
    green = color.green;
    blue = color.blue;
    
    // Apply gamma correction
    float r = (red   > 0.04045f) ? pow((red   + 0.055f) / (1.0f + 0.055f), 2.4f) : (red   / 12.92f);
    float g = (green > 0.04045f) ? pow((green + 0.055f) / (1.0f + 0.055f), 2.4f) : (green / 12.92f);
    float b = (blue  > 0.04045f) ? pow((blue  + 0.055f) / (1.0f + 0.055f), 2.4f) : (blue  / 12.92f);
    
    // Wide gamut conversion D65
    float X = r * 0.664511f + g * 0.154324f + b * 0.162028f;
    float Y = r * 0.283881f + g * 0.668433f + b * 0.047685f;
    float Z = r * 0.000088f + g * 0.072310f + b * 0.986039f;
    
    float cx = X / (X + Y + Z);
    float cy = Y / (X + Y + Z);
    
    if (isnan(cx)) {
        cx = 0.0f;
    }
    
    if (isnan(cy)) {
        cy = 0.0f;
    }
    
    //Check if the given XY value is within the colourreach of our lamps.
    
    CGPoint xyPoint =  CGPointMake(cx,cy);
    ColorPoints  colorPoints = colorPointsForModel(model);
    int inReachOfLamps = checkPointInLampsReach (xyPoint,colorPoints);
    
    if (!inReachOfLamps) {
        //It seems the colour is out of reach
        //let's find the closest colour we can produce with our lamp and send this XY value out.
        
        //Find the closest point on each line in the triangle.
        CGPoint pAB =getClosestPointToPoints(colorPoints.red, colorPoints.green, xyPoint);
        CGPoint pAC = getClosestPointToPoints(colorPoints.blue, colorPoints.red, xyPoint);
        CGPoint pBC = getClosestPointToPoints(colorPoints.green, colorPoints.blue, xyPoint);
        
        //Get the distances per point and see which point is closer to our Point.
        float dAB = getDistanceBetweenTwoPoints(xyPoint, pAB);
        float dAC = getDistanceBetweenTwoPoints(xyPoint, pAC);
        float dBC = getDistanceBetweenTwoPoints(xyPoint, pBC);
        
        float lowest = dAB;
        CGPoint closestPoint = pAB;
        
        if (dAC < lowest) {
            lowest = dAC;
            closestPoint = pAC;
        }
        if (dBC < lowest) {
            lowest = dBC;
            closestPoint = pBC;
        }
        
        //Change the xy value to a value which is within the reach of the lamp.
        cx = closestPoint.x;
        cy = closestPoint.y;
    }
    
    return CGPointMake(cx, cy);
}

const char* calcRGB (const char *model, const char *xy){
    float x,y;
    sscanf(xy, "%f,%f", &x,&y);
    static char s[7];
    Color color = colorFromXY (CGPointMake(x,y),model);
    int r,g,b;
    r = 250 * color.red;g = 250 * color.green;b = 250 * color.blue;
    snprintf(s, 7, "%02X%02X%02X", r,g,b);
    return s;
}

const char* realRGB (const char *rgb){
    int i, j;
    j = 0;
    for (i = 0 ; i < colorcount; i++) {
        if (strcasecmp(rgb, colornames[i]) == 0) {
            j = i;
            break;
        }
    }
    if (j) return colorsrgb[j];
    return rgb;
}

const char* calcXY (const char *model, const char *rgb){
    unsigned int x = 0; unsigned int y = 0; unsigned int z = 0;
    const char *s = rgb;
    const char *t;
    while (strncasecmp(s,"#",1) == 0 || strncasecmp(s,"0x",2) == 0  || strncasecmp(s,"x",1) == 0 ){
        s = strndup(s+ 1, strlen(s) - 1);
    }
    int i;
    t=s;
    for (i = 0 ; i < colorcount; i++) {
        if (strcasecmp(s, colornames[i]) == 0) {
            t=colorsrgb[i];
        }
    }
    sscanf(t, "%2x%2x%2x", &x,&y,&z);
    Color color;
    color.red = (float) x / 255;
    color.green = (float) y / 255;
    color.blue = (float) z / 255;
    CGPoint x_y = calculateXY(color,model);
    static char ss[14];
    snprintf(ss, 14, "%.4f,%.4f\n", x_y.x, x_y.y);
    return ss;
}

const char* listColors (const char *start) {
    unsigned long l = strlen(start);
    int i, j;
    j = 0;
    const char *s[colorcount];
    for (i = 0; i < colorcount; i++) {
        if (l == 0 || strncasecmp(colornames[i],start,l) == 0) {
            unsigned long buffersize = strlen(colornames[i]) + 4 + strlen(colorsrgb[i]);
            char *buffer = malloc(buffersize);
            if (buffer == NULL) {
                printf("No memory for buffer!\n");
            }
            snprintf(buffer, buffersize, "%s: #%s", colornames[i], colorsrgb[i]); // return the str
            s[j] = buffer;
            j++;
            // free(buffer);
        }
    }
    return join_strings((char **) s, "\n", j);


}

