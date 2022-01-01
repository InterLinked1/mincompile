#!/bin/sh

# mincompile (C) InterLinked, 2021

MINCOMPILE_MAKE=ccache # use ccache if possible
USESKIPFILE=0
SKIPFILE=""
if ! which ccache > /dev/null; then
	MINCOMPILE_MAKE=make # fall back to make
fi

PARSED_ARGUMENTS=$(getopt -n mincompile -o s: -l skip: -- "$@")
if [ $? -ne 0 ]; then
	printf "%s\n" "Invalid usage"
	exit 1
fi
eval set -- "$PARSED_ARGUMENTS"
while true; do
	case "$1" in
		-s | --skip ) SKIPFILE=$2; shift 2;; # file containg list of filenames to skip
		# -- means the end of the arguments; drop this, and break out of the while loop
		--) shift; break ;;
		# If invalid options were passed, then getopt should have reported an error,
		# which we checked as VALID_ARGUMENTS when getopt was called...
		*) echo "Unexpected option: $1"
			shift; exit 1; break ;;
	esac
done

if [ ${#SKIPFILE} -gt 0 ]; then
	if [ ! -f "$SKIPFILE" ]; then
		printf "Skip file '%s' does not exist\n" "$SKIPFILE"
		exit 1
	fi
	USESKIPFILE=1
fi

make
if [ $? -ne 0 ]; then
	printf "Program does not compile to begin with, exiting\n"
	exit 1
fi
files=$( find -name '*.c' | sort )
IFS='
'

for f in $files; do
	if [ $USESKIPFILE -eq 1 ]; then
		if grep -Fxq "$f" "$SKIPFILE"; then
			printf "Skipping '%s'...\n" "$f"
			continue
		fi
	fi
	if [ ! -f "$f" ]; then
		printf "How can file %s not exist?" "$f"
		exit 1
	fi
	if grep -Fq "//UNNECESSARY #" "$f"; then
		printf "Skipping already parsed '%s'\n" "$f"
		continue
	fi
	if grep -Fq "//TEST#" "$f"; then
		printf "Skipping already parsed '%s'\n" "$f"
		continue
	fi
	if [ ! -f "$f.orig" ]; then
		cp "$f" "$f.orig" # orig backup
	fi
	includes=$( grep '#include' "$f" )
	withoutextension=`printf '%s\n' "$f" | sed -r 's|^(.*?)\.\w+$|\1|'`
	objectfile="$withoutextension.o"
	if [ ! -f "$objectfile" ]; then
		printf "Skipping uncompiled file '%s'\n" "$f"
		continue
	fi
	originalhash=$( md5sum "$objectfile" | cut -d' ' -f1 )
	for include in $includes; do # check if each include in this file is necessary
		printf "Processing include directive %s\n" "$include"
		sed -i "s|${include}|//TEST${include}|g" "$f"
		$MINCOMPILE_MAKE make >/dev/null 2>/dev/null
		if [ $? -ne 0 ]; then # if it won't compile without that header file, it's definitely necessary
			printf "Include directive %s is explicitly necessary in %s\n" "$include" "$f"
			sed -i "s|//TEST${include}|${include}|g" "$f" # undo
		else
			newhash=$( md5sum "$objectfile" | cut -d' ' -f1 ) # does the compiled binary change? If so, the behavior changed, so it's still necessary
			if [ "$originalhash" = "$newhash" ]; then
				printf "Include directive %s is NOT necessary in %s\n" "$include" "$f"
				sed -i "s|//TEST${include}|//UNNECESSARY ${include}|g" "$f" # mark as unnecessary for sure
			else
				printf "Include directive %s is implicitly necessary in %s\n" "$include" "$f"
				sed -i "s|//TEST${include}|${include}|g" "$f" # revert removal
			fi
		fi
		sleep 0.1
	done
done
