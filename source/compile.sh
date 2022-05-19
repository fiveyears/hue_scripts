#!/bin/bash
cleanUp () {
	rm -f libTools.so json.txt json1.txt
	rm -f libToolsv1.so
	rm -f ../bin/hello1.tcl
	rm -f ../bin/hello2.tcl
	rm -f ../bin/json.txt ../bin/json1.txt jsondump mdns newudp getglib32 getglib64 *.o Makefile
}

writeTcl () {
	i_writeTcl () {
		v=${1:-"1"}
		if [ "$v" == "1" ]; then
			v1="";v2="#"; nr=1
			cat >| ../bin/json1.txt <<EOF
{"01":{"state":{"on":false,"bri":254,"hue":34079,"sat":251,"effect":"none","xy":[0.3144,0.3301],"ct":153,"alert":"none","colormode":"xy","mode":"homeautomation","reachable":true},"swupdate":{"state":"noupdates","lastinstall":"2017-11-30T13:17:04"},"type":"Extended color light","name":"Hue TV","modelid":"LCT001","manufacturername":"Philips","capabilities":{"streaming":{"renderer":true,"proxy":false}},"uniqueid":"00:17:88:01:00:fc:1f:eb-0b","swversion":"5.105.0.21169"},"02":{"state":{"on":false,"bri":127,"hue":8904,"sat":106,"effect":"none","xy":[0.4647,0.3824],"ct":375,"alert":"none","colormode":"xy","mode":"homeautomation","reachable":true},"swupdate":{"state":"noupdates","lastinstall":"2017-11-30T13:18:04"},"type":"Extended color light","name":"D2","modelid":"LCT001","manufacturername":"Philips","capabilities":{"streaming":{"renderer":true,"proxy":false}},"uniqueid":"00:17:88:01:00:f9:66:65-0b","swversion":"5.105.0.21169"}}
EOF
		else
			v2="";v1="#"; nr=
			cat >| ../bin/json.txt <<EOF
{[{"state":{"on":false,"bri":254,"hue":34079,"sat":251,"effect":"none","xy":[0.3144,0.3301],"ct":153,"alert":"none","colormode":"xy","mode":"homeautomation","reachable":true},"swupdate":{"state":"noupdates","lastinstall":"2017-11-30T13:17:04"},"type":"Extended color light","name":"Hue TV","modelid":"LCT001","manufacturername":"Philips","capabilities":{"streaming":{"renderer":true,"proxy":false}},"uniqueid":"00:17:88:01:00:fc:1f:eb-0b","swversion":"5.105.0.21169"},{"state":{"on":false,"bri":127,"hue":8904,"sat":106,"effect":"none","xy":[0.4647,0.3824],"ct":375,"alert":"none","colormode":"xy","mode":"homeautomation","reachable":true},"swupdate":{"state":"noupdates","lastinstall":"2017-11-30T13:18:04"},"type":"Extended color light","name":"D2","modelid":"LCT001","manufacturername":"Philips","capabilities":{"streaming":{"renderer":true,"proxy":false}},"uniqueid":"00:17:88:01:00:f9:66:65-0b","swversion":"5.105.0.21169"}]}
EOF
		fi
		cat >| ../bin/hello$v.tcl <<EOF 
#!/usr/bin/env tclsh
if {[package vcompare [package provide Tcl] 8.4] < 0} {
	set script_path [file dirname \$argv0]
} else {
	set script_path [file normalize [file dirname \$argv0]]
}
load \$script_path/../bin/libTools[info sharedlibextension]
${v2}source [file join \$script_path/.. "hue.inc.tcl"]
${v2}source [file join \$script_path/.. "hue2.inc.tcl"]
${v1}source [file join \$script_path/.. "hue.inc.tcl"]
set s "\$script_path/json$nr.txt"
${v1}puts "v1 ...\n"
${v1}eval [string map { \[ \{ \] \} } [jsonparser light \$s]]
${v1}parray light
${v2}puts "\nv2 ...\n"
${v2}set s [ exec cat \$s | ../bin/jsondump ]
${v2}eval [ readYaml \$s  light "" "" 1]
${v2}parray light
puts "RealRGB red"
puts [realRGB red]
EOF
		chmod 755 ../bin/hello$v.tcl
	}
	i_writeTcl 1
	i_writeTcl 2
	unset -f i_writeTcl
}

dir=$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd) && cd $dir 
test -d "/Volumes/SSD/Develop/web"  && webdir="$_/docker"
test -x "$HOME/opt/bin/docker.sh"  && webdir="$HOME/opt/bin"
only=4
if [[ $1 == -o ]]; then
	only=1
	shift
elif [[ $2 == -o ]]; then
	only=1
elif [[ $1 == -m ]]; then
	only=2
	shift
elif [[ $2 == -m ]]; then
	only=2
elif [[ $1 == -t ]]; then
	only=3
	shift
elif [[ $2 == -t ]]; then
	only=3
fi
para=$1
if [ "$para" == "-h"  -o -z "$para" ]; then
	echo "Usage: $(basename $0) [-h | -a | -l | -r | -u] [-o | -m | -t]"
	echo "          -h (or empty)   this help"
	echo "          -a              compile local and remote per ubuntu"
	echo "          -l              compile local"
	echo "          -r              compile for remote per dockcross"
	echo "          -u              compile for remote per ubuntu"
	echo "              -t          compile and test too"
	echo "              -o          only testing and no compiling"
	echo "              -m          only testing including mdns, no compiling"
	exit 0
fi
if [ -z "$webdir" ]; then
	if [ "$para" == "-r" -o "$para" == "-a" -o "$para" == "-t"  ]; then
		echo
		echo "Error: docker.sh not found!"
		echo "Coudn't start docker for compiling remote."
		echo
		exit 
	fi
elif [[ ! ${para:1:1} =~ l|t|a|r|u ]]; then	echo
	echo "'$para' wrong parameter!"
	echo "exit!"
	echo
	exit
fi
M1=$(uname -m) # arm64
writeTcl
#
#local compilation 
#

if [[ ${para:1:1} =~ l|t|a ]]; then
	echo local:
	if [ $only -ge 3 ]; then
		echo "    compiling ..."
		./clang.sh newudp
		./clang.sh mdns
		./clang.sh jsondump
		./clang.sh -tcl libTools color hello
		mv newudp ../bin
		mv mdns ../bin
		mv jsondump ../bin
		mv libTools.dylib ../bin/v2
		./clang.sh -tcl libTools colorv1 hellov1
		mv libTools.dylib ../bin
	fi
	if [  $only -lt 4 ]; then
		echo "test jsondump:"
		echo '{"Hans" : "Peter", "Karl": [1, 2, 3]}' | ../bin/jsondump 
		echo "test newudp:"
		../bin/newudp 
		../bin/hello1.tcl
		../bin/hello2.tcl
		[[ $only == 2 ]] && echo -n "test mdns: " && ../bin/mdns | grep hue | grep -v '\[' | cut -f 1 -d ":"
	fi
fi
#
#cross compilation via docker and copy to raspi
#
if [[ ${para:1:1} =~ r|t ]]; then
	ping -c1 -W1 192.168.2.30 &>/dev/null
	if [ $? != 0 ]; then
		echo "Raspimatic not started!"
		cleanUp
		exit 0
	else
		ccu=ccu
		ddd="/Users/ivo/Dropbox/web/hue/bin_raspi_$(date +%Y%m%d_%H%M%S)"
		mkdir -p "$ddd"
		scp ${ccu}:/usr/local/scripts/hue/bin/v2/libTools.so "$ddd/libTools.so" 1>/dev/null
		scp ${ccu}:/usr/local/scripts/hue/bin/libTools.so "$ddd/libToolsv1.so" 1>/dev/null
		scp ${ccu}:/usr/local/scripts/hue/bin/mdns "$ddd/mdns" 1>/dev/null
		scp ${ccu}:/usr/local/scripts/hue/bin/jsondump "$ddd/jsondump" 1>/dev/null
		scp ${ccu}:/usr/local/scripts/hue/bin/newudp "$ddd/newudp" 1>/dev/null
		scp ${ccu}:/usr/local/scripts/hue/bin/getglib32 "$ddd/getglib32" 1>/dev/null
		scp ${ccu}:/usr/local/scripts/hue/bin/getglib64 "$ddd/getglib64" 1>/dev/null
	fi

# jsondump wrong version `GLIBC_2.34' compile -static
# newudp wrong version `GLIBC_2.34' compile -static
# mdns wrong version `GLIBC_2.34' compile -static
#static="-static"
# no use of -DUSE_TCL_STUBS anymore
	echo "raspi via dockercross"
	if [ $only -ge 3 ]; then
		source $webdir/docker.sh
		TCLINC=./tcl-header
		if [ "$M1" = "arm64" ]; then
			export DOCKCROSS_ARGS="--platform linux/amd64"
		fi
		echo "  compiling getglib 32 ..." && ./dockcross-armv7  bash -c "\$CC  $static getglib.c -o getglib32"
		echo "  compiling getglib 64 ..." && ./dockcross-armv64 bash -c "\$CC  $static getglib.c -o getglib64"
		echo "  compiling jsondump ..."   && ./dockcross-armv64 bash -c "\$CC  $static jsondump.c -o jsondump"
		echo "  compiling newudp ..."     && ./dockcross-armv64 bash -c "\$CC  $static newudp.c -o newudp"
		echo "  compiling mdns ..."       && ./dockcross-armv64 bash -c "\$CC  $static mdns.c -o mdns"
		echo "  compiling color.c ..."    && ./dockcross-armv64  bash -c "\$CC -fPIC -c color.c -o color.o"
		echo "  compiling libTools ..."   && ./dockcross-armv64  bash -c "\$CC -fPIC -std=gnu99 -shared -o libTools.so  -I$TCLINC hello.c  color.o"
		echo "  compiling colorv1.c ..."  && ./dockcross-armv64  bash -c "\$CC -fPIC -c colorv1.c -o colorv1.o"
		echo "  compiling libToolsv1 ..." && ./dockcross-armv64  bash -c "\$CC -fPIC -std=gnu99 -shared -o libToolsv1.so  -I$TCLINC hellov1.c  colorv1.o"
		ssh ${ccu} "cd /usr/local/scripts/hue/bin && rm -f libTools.so mdns jsondump getglib32 getglib64 newudp v2/libTools.so hello1.tcl hello2.tcl json.txt"
		scp libTools.so ${ccu}:/usr/local/scripts/hue/bin/v2/libTools.so 1>/dev/null
		scp libToolsv1.so ${ccu}:/usr/local/scripts/hue/bin/libTools.so 1>/dev/null
		scp mdns jsondump newudp getglib32 getglib64 ${ccu}:/usr/local/scripts/hue/bin/ 1>/dev/null
	fi
	if [  $only -lt 4 ]; then
		scp ../bin/hello1.tcl ../bin/hello2.tcl ../bin/json.txt ../bin/json1.txt  ${ccu}:/usr/local/scripts/hue/bin/ 1>/dev/null
ssh ${ccu} /bin/sh <<EOF 
cd /usr/local/scripts/hue/bin
echo
echo -n "getglib32: "
./getglib32
echo -n "getglib64: "
./getglib64
echo
./hello1.tcl
./hello2.tcl
rm -f hello1.tcl hello2.tcl json.txt json1.txt
echo "test jsondump:"
echo '{"Hans" : "Peter", "Karl": [1, 2, 3]}' | ./jsondump 
echo "test newudp:"
./newudp 
EOF
		[[ $only == 2 ]] && echo -n "test mdns: " && ssh ${ccu} "/usr/local/scripts/hue/bin/mdns | grep hue |grep -v '\[' | cut -f 1 -d ':'"

	fi
fi
if [[ ${para:1:1} =~ u|t|a ]]; then
	ping -c1 -W1 192.168.2.160 &>/dev/null
	if [ $? != 0 ]; then
		echo "Ubuntu not started!"
		cleanUp
		exit 0
	else
		ub=ub
	fi
	ping -c1 -W1 192.168.2.30 &>/dev/null
	if [ $? != 0 ]; then
		echo "Raspimatic not started!"
		cleanUp
		exit 0
	else
		ccu=ccu
		ddd="/Users/ivo/Dropbox/web/hue/bin_raspi_$(date +%Y%m%d_%H%M%S)"
		mkdir -p "$ddd"
		scp ${ccu}:/usr/local/scripts/hue/bin/v2/libTools.so "$ddd/libTools.so" 1>/dev/null
		scp ${ccu}:/usr/local/scripts/hue/bin/libTools.so "$ddd/libToolsv1.so" 1>/dev/null
		scp ${ccu}:/usr/local/scripts/hue/bin/mdns "$ddd/mdns" 1>/dev/null
		scp ${ccu}:/usr/local/scripts/hue/bin/jsondump "$ddd/jsondump" 1>/dev/null
		scp ${ccu}:/usr/local/scripts/hue/bin/newudp "$ddd/newudp" 1>/dev/null
		scp ${ccu}:/usr/local/scripts/hue/bin/getglib32 "$ddd/getglib32" 1>/dev/null
		scp ${ccu}:/usr/local/scripts/hue/bin/getglib64 "$ddd/getglib64" 1>/dev/null
	fi

	echo "ubuntu and buildroot"
	if [ $only -ge 3 ]; then
# -lm at the end for math.h
cat << EOF > Makefile

CROSS   := /usr/bin/
CC      := \$(CROSS)gcc

ifeq (\$(OS), Windows_NT)
        detected_OS := Windows
else
        detected_OS := \$(shell uname)
endif

ifeq (\$(detected_OS),Darwin)
        STRIP = \$(CROSS)strip -x
else
        STRIP = \$(CROSS)strip --strip-unneeded
endif

BINS    := jsondump mdns newudp
CROSS3  := /home/ivo/Documents/develop/RaspberryMatic/build-raspmatic_rpi3/host/bin/
CC3     := \$(CROSS3)aarch64-buildroot-linux-gnu-gcc
STRIP3  := \$(CROSS3)aarch64-buildroot-linux-gnu-strip --strip-unneeded
CROSS4  := /home/ivo/Documents/develop/RaspberryMatic/build-raspmatic_rpi4/host/bin/
CC4     := \$(CROSS4)aarch64-buildroot-linux-gnu-gcc
STRIP4  := \$(CROSS4)aarch64-buildroot-linux-gnu-strip --strip-unneeded
CROSS2  := /home/ivo/Documents/develop/RaspberryMatic/build-raspmatic_rpi2/host/bin/
CC2     := \$(CROSS2)arm-buildroot-linux-gnueabihf-gcc
STRIP2  := \$(CROSS2)arm-buildroot-linux-gnueabihf-strip
CROSST  := /home/ivo/Documents/develop/RaspberryMatic/build-raspmatic_tikerboard/host/bin/
CCT     := \$(CROSST)arm-buildroot-linux-gnueabihf-gcc
STRIPT  := \$(CROSST)arm-buildroot-linux-gnueabihf-strip
C_FLAGS := -pedantic -Wno-format-truncation -fPIC
# L_FLAGS := -Wno-format-truncation -fPIC -std=gnu99 -shared -DUSE_TCL_STUBS  -o
L_FLAGS := -Wno-format-truncation -fPIC -std=gnu99 -shared -o

RASPI_CC := \$(CC3)
RASPI_STRIP := \$(STRIP3)

.PHONY: test all clean

all: \$(BINS) color getglib

test:
	@echo OS: \$(detected_OS)
	@echo 
	@echo CC: \$(CC)
	@echo STRIP: \$(STRIP)
	@echo 
	@echo CC2: \$(CC2)
	@echo STRIP2: \$(STRIP2)
	@echo 
	@echo CC3: \$(CC3)
	@echo STRIP3: \$(STRIP3)
	@echo 
	@echo CC4: \$(CC4)
	@echo STRIP4: \$(STRIP4)
	@echo 
	@echo BINS: \$(BINS)

%: %.c
	\$(CC) \$(C_FLAGS) \$< -o \$@
	\$(STRIP) \$@
	\$(RASPI_CC) \$(C_FLAGS) \$< -o raspi/\$@
	\$(RASPI_STRIP) raspi/\$@

color:
	\$(CC) \$(C_FLAGS) -c color.c   -o color.o
	\$(CC) \$(C_FLAGS) -c colorv1.c -o colorv1.o
	\$(CC) \$(L_FLAGS) v2/libTools.so hello.c color.o
	\$(CC) \$(L_FLAGS) libTools.so hellov1.c colorv1.o
	\$(STRIP) libTools.so v2/libTools.so
	\$(CC3) \$(C_FLAGS) -c color.c   -o raspi/color.o
	\$(CC3) \$(C_FLAGS) -c colorv1.c -o raspi/colorv1.o
	\$(CC3) -I. \$(L_FLAGS) raspi/v2/libTools.so hello.c raspi/color.o
	\$(CC3) -I. \$(L_FLAGS) raspi/libTools.so hellov1.c raspi/colorv1.o
	\$(STRIP3) raspi/libTools.so raspi/v2/libTools.so
	@rm -f *.o raspi/*.o

getglib:
	\$(CC) \$(C_FLAGS) getglib.c -o getglib
	\$(STRIP) getglib
	\$(RASPI_CC) \$(C_FLAGS) getglib.c -o raspi/getglib64
	\$(RASPI_STRIP) raspi/getglib64
	\$(CC2) \$(C_FLAGS) getglib.c -o raspi/getglib32
	\$(STRIP2) raspi/getglib32


clean:
	@rm -f \$(BINS) getglib *.o *.so *.tcl *.txt
	@find raspi -type f -delete
	@rm -f v2/*.so
EOF
		ssh ${ub} "mkdir -p Documents/develop/hue/bin/v2/ && mkdir -p Documents/develop/hue/bin/raspi/v2"
		scp Makefile getglib.c hello.c hellov1.c jsmn.h jsondump.c color.c colorv1.c color.h colorv1.h mdns.h mdns.c newudp.c ${ub}:"Documents/develop/hue/bin/" 1>/dev/null
		scp ./tcl-header/tcl.h ${ub}:"Documents/develop/hue/bin/" 1>/dev/null
		scp ./tcl-header/tclDecls.h ${ub}:"Documents/develop/hue/bin/" 1>/dev/null
		ssh ${ub} "cd Documents/develop/hue/bin/ && make clean && make"
		scp -3 ${ub}:Documents/develop/hue/bin/raspi/jsondump ${ccu}:/usr/local/scripts/hue/bin
		scp -3 ${ub}:Documents/develop/hue/bin/raspi/mdns ${ccu}:/usr/local/scripts/hue/bin
		scp -3 ${ub}:Documents/develop/hue/bin/raspi/getglib64 ${ccu}:/usr/local/scripts/hue/bin
		scp -3 ${ub}:Documents/develop/hue/bin/raspi/getglib32 ${ccu}:/usr/local/scripts/hue/bin
		scp -3 ${ub}:Documents/develop/hue/bin/raspi/newudp ${ccu}:/usr/local/scripts/hue/bin
		scp -3 ${ub}:Documents/develop/hue/bin/raspi/libTools.so ${ccu}:/usr/local/scripts/hue/bin
		scp -3 ${ub}:Documents/develop/hue/bin/raspi/v2/libTools.so ${ccu}:/usr/local/scripts/hue/bin/v2
	fi
	if [  $only -lt 4 ]; then
		scp ../bin/hello1.tcl ../bin/hello2.tcl ../bin/json.txt ../bin/json1.txt ${ub}:"Documents/develop/hue/bin/" 1>/dev/null
		scp ../bin/hello1.tcl ../bin/hello2.tcl ../bin/json.txt ../bin/json1.txt ${ccu}:"/usr/local/scripts/hue/bin/" 1>/dev/null
ssh ${ub} /bin/sh <<EOF 
echo Ubuntu
echo
cd Documents/develop/hue/bin
./getglib
echo
export PATH=/home/ivo/bin/:\$PATH
./hello1.tcl
./hello2.tcl
rm -f hello1.tcl hello2.tcl json.txt
echo "test jsondump:"
echo '{"Hans" : "Peter", "Karl": [1, 2, 3]}' | ./jsondump 
echo "test newudp:"
./newudp 
EOF
		[[ $only == 2 ]] && echo -n "test mdns: "  && ssh ${ub} " cd Documents/develop/hue/bin && ./mdns | grep hue |grep -v '\[' | cut -f 1 -d ':'"
ssh ${ccu} /bin/sh <<EOF 
echo
echo Raspimatic
echo
cd /usr/local/scripts/hue/bin
./getglib64
./getglib32
echo
./hello1.tcl
./hello2.tcl
rm -f hello1.tcl hello2.tcl json.txt json1.txt
echo "test jsondump:"
echo '{"Hans" : "Peter", "Karl": [1, 2, 3]}' | ./jsondump 
echo "test newudp:"
./newudp 
EOF
		[[ $only == 2 ]] && echo -n "test mdns: "  && ssh ${ccu} " cd /usr/local/scripts/hue/bin && ./mdns | grep hue |grep -v '\[' | cut -f 1 -d ':'"
	fi
ssh ${ub} /bin/sh <<EOF
cd Documents/develop/hue/bin
rm -f *.h *.c Makefile
rm -rf raspi/
EOF

fi
cleanUp
