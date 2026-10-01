#!/bin/zsh
# Created with /Users/ivo/Dropbox/Shell-Scripts/cmd/crea at 2022-05-26 07:47:08
hue="$HOME/Dropbox/web/hue"
dest="$hue"
cp "$hue/source/color.c" "$dest/color.cpp"
cp "$hue/source/color.h" "$dest/color.h"
sed -i '' 's/^const char\*/client::String*/g' "$dest/color.h"
t="$(mktemp)"
echo "#include <cheerp/clientlib.h>" >| "$t"
cat "$dest/color.h" >> "$t"
mv "$t" "$dest/color.h"
sed -i '' 's/^const char \* realXY/const char* realXY/g' "$dest/color.cpp"
sed -i '' 's/^const char\* join_strings/const char * join_strings/g' "$dest/color.cpp"
sed -i '' 's/^const char\*/[[cheerp::jsexport]] client::String*/g' "$dest/color.cpp"
sed -i '' 's/^const char \* join_strings/const char* join_strings/g' "$dest/color.cpp"
sed -i '' 's/return s;/return client::String::fromUtf8(s,7);/g' "$dest/color.cpp"
sed -i '' 's/return colorsrgb\[j\];/return client::String::fromUtf8(colorsrgb[j],strlen(colorsrgb[j]));/g' "$dest/color.cpp"
sed -i '' 's/return rgb;/return client::String::fromUtf8(rgb,strlen(rgb));/g' "$dest/color.cpp"
sed -i '' 's/return ss1;/return client::String::fromUtf8(ss1,14);/g' "$dest/color.cpp"
sed -i '' 's/return ss;/return client::String::fromUtf8(ss,14);/g' "$dest/color.cpp"
sed -i '' 's/return join_strings\(.*\)/const char* s3 = join_strings\1\n    return client::String::fromUtf8(s3,strlen(s3));/g' "$dest/color.cpp"
sed -i '' 's/str = malloc/str = (char*)malloc/g' "$dest/color.cpp"
sed -i '' 's/buffer = malloc/buffer = (char*)malloc/g' "$dest/color.cpp"
sed -i '' 's/"\\n"/(char*)"\\n"/g' "$dest/color.cpp"
sed -i '' 's/float crossProduct\(.*\);/float crossProduct\1;\nchar* getChar(const client::String\& start);/g' "$dest/color.cpp"
sed -i '' 's/\(float crossProduct\)\(.*\){/char* getChar(const client::String\& start) {\n     int i = start.get_length();\n     char* c = (char *) malloc(i);\n     for (int j = 0; j < i; j++) {\n         c[j] = start.charCodeAt(j);\n     }\n     return c;\n }\n\n\1\2{/g' "$dest/color.cpp"
# parameter
sed -i '' 's/(const char \*/(const client::String\& _/g' "$dest/color.h"
sed -i '' 's/(const char \*\(.*\)\(, float redX\)\(.*\)/(const client::String\& _\1\2\3\n    char* \1 = getChar(_\1);/g' "$dest/color.cpp"
sed -i '' 's/(const char \*\(.*\))\(.*\)/(const client::String\& _\1)\2\n    char* \1 = getChar(_\1);/g' "$dest/color.cpp"

echo "void webMain()
{
    // client::console.log(\"ready\");
}
"  >> "$dest/color.cpp"

/Applications/cheerp/bin/clang++ -target cheerp "$dest/color.cpp" -o "$dest/color.js"
rm -f  "$dest/color.cpp"
rm -f  "$dest/color.h"
sed -i '' -e 's/\/\*Compiled using Cheerp (R) by Leaning Technologies Ltd\*\///g' "$dest/color.js"