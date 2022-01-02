#!/bin/zsh
# Created with /Users/ivo/Dropbox/Shell-Scripts/cmd/crea at 2021-12-23 09:22:29
dir=$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)
cd $dir
export LANG\=en_US.US-ASCII
CC=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang
isysroot="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
target=apple-macos12.0
opt="
 -fmessage-length=0
 -fdiagnostics-show-note-include-stack
 -fmacro-backtrace-limit=0
 -std=gnu11
 -fmodules
 -gmodules
 -fmodules-prune-interval=86400
 -fmodules-prune-after=345600
 -Wnon-modular-include-in-framework-module
 -Werror=non-modular-include-in-framework-module
 -Wno-trigraphs
 -fpascal-strings
 -Os
 -fno-common
 -Wno-missing-field-initializers
 -Wno-missing-prototypes
 -Werror=return-type
 -Wdocumentation
 -Wunreachable-code
 -Wquoted-include-in-framework-header
 -Werror=deprecated-objc-isa-usage
 -Werror=objc-root-class
 -Wno-missing-braces
 -Wparentheses
 -Wswitch
 -Wunused-function
 -Wno-unused-label
 -Wno-unused-parameter
 -Wunused-variable
 -Wunused-value
 -Wempty-body
 -Wuninitialized
 -Wconditional-uninitialized
 -Wno-unknown-pragmas
 -Wno-shadow
 -Wno-four-char-constants
 -Wno-conversion
 -Wconstant-conversion
 -Wint-conversion
 -Wbool-conversion
 -Wenum-conversion
 -Wno-float-conversion
 -Wnon-literal-null-conversion
 -Wobjc-literal-conversion
 -Wpointer-sign
 -Wno-newline-eof
 -fstrict-aliasing
 -Wdeprecated-declarations
 -g
 -fvisibility=hidden
 -Wno-sign-conversion
 -Winfinite-recursion
 -Wcomma
 -Wblock-capture-autoreleasing
 -Wstrict-prototypes
 -Wno-semicolon-before-method-body
 -Wunguarded-availability
 -I $dir
"
if [ "$1" = "-tcl" ]; then
  if [ -z "$2" ]; then
    echo "No Tcl-Lib-Name!"
    exit 1
  fi
  file="$2"
  ending=".dylib"
  shift
  shift
  tclCompilerOpts=-DUSE_TCL_STUBS
  tclLinkerOpts_x86_64=(-ltclstub8.5 -dynamiclib)
  tclLinkerOpts_arm64=(-ltclstub8.6 -dynamiclib)
else
  file="${1:-mdns}"
  ending=""
  tclCompilerOpts=
  tclLinkerOpts_x86_64=
  tclLinkerOpts_arm64=
fi
files=""
for var in "$@"
do
  files=($files $var.o)
  $CC \
   -x c \
   -target x86_64-$target \
   $tclCompilerOpts \
   $=opt \
   -isysroot "$isysroot" \
   -fasm-blocks \
   -c "$var.c" \
   -o "$var.o"
done
$CC \
  -target x86_64-$target \
  -isysroot "$isysroot" \
  -L  $dir \
  -F  $dir \
  $=tclLinkerOpts_x86_64 \
  $=files \
  -o "${file}_x86_64$ending"

for var in "$@"
do
  $CC \
   -x c \
   -target arm64-$target \
   $tclCompilerOpts \
    $=opt \
   -isysroot "$isysroot" \
   -c "$var.c" \
   -o "$var.o"
done

$CC \
 -target arm64-$target \
  -isysroot "$isysroot" \
  -L $dir \
  -F $dir \
  $=tclLinkerOpts_arm64 \
  $=files \
  -o "${file}_arm64$ending"

lipo "${file}_arm64$ending" "${file}_x86_64$ending" -create  -output "${file}$ending"

# clean-up
rm -f ${file}_arm64$ending ${file}_x86_64$ending *.o