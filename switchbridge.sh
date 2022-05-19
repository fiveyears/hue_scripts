#!/bin/sh
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "$HOME" = "/root" ]; then
	config="$dir/bin/.hue"
else
	config="$HOME/.hue"
fi
var="$(echo $1 | tr '[:upper:]' '[:lower:]')"
if [ "${var:0:2}" = "-h" -o  "${var:0:3}" = "--h" ]; then
	f=$(basename "$0")
	echo "Usage $f:"
	echo "   $f -h | --help     ... this help"
	echo "   $f -s | --show     ... Show current bridge"
	echo "   $f -q | --quit     ... same as -s"
	echo
	echo "   $f <Bridge name>   ... set this bridge"
	echo "   $f <Bridge number> ... set this bridge"
	echo
	exit 0
elif [ "${var:0:2}" = "-s" -o  "${var:0:3}" = "--s" ]; then
	var=s
elif [ "${var:0:2}" = "-q" -o  "${var:0:3}" = "--q" ]; then
	var=q
fi

if [ "$(head -n 1 "$config/0/info.txt"| tr '[:upper:]' '[:lower:]')" = "$var" ]; then
	echo "Bridge $1 already set!"
	exit 0
fi

echo "\033[1mCurrent used bridge:\033[0m\nBridge: \c"
cat "$config/0/info.txt" 
echo
echo "\033[1mFound bridges:\033[0m"
echo
files=$(find $config ! -path "*/0/*" -iname info.txt -print | sort)
i=0
for file in $files; do
	i=$((i  + 1))
	echo "$i: Bridge \c"
	bridge=$(head -n 1 "$file")
	if [ "$(echo $bridge | tr '[:upper:]' '[:lower:]' )" = "$var" ]; then 
		var=$i
		echo "$bridge selected"
		break
	fi 
	echo "$bridge ($(tail -n 1 "$file" | sed "s/^ *//" | tr '[:upper:]' '[:lower:]' ))"
	echo
done
if [ "$i" -eq "0" ]; then
	echo "No other bridge found!"
	exit 0
fi
if [ "$i" -eq "1" ]; then
	ch="Choose from $i"
else
	ch="Choose from 1 thru $i"
fi
while [[ ! $var =~ ^[1-$i|q|Q|s|S]{1} ]]; do
	echo
    echo "$ch (or quit with q): \c"
	read -n1 var
done
echo 
if [ "$var" = "s" -o "$var" = "S" ]; then
	exit 0
elif [ "$var" = "q" -o "$var" = "Q" ]; then
	exit 0
fi
mv "$config/$var/" "$config/xxx/"
mv "$config/0/" "$config/$var/"
mv "$config/xxx/" "$config/0/"

