#!/bin/bash

pid_file=/tmp/pid.my

print_help() {
	echo "
Usage: $0 [-h|-t] -- ...
	-h	print this help
	-v	print some additional info
	-t 	do optional testing to be sure that orphan is still alive
"
	exit 1
}

if [ 0 -eq $# ]; then
	print_help
fi

while true; do
	case "$1" in
	-h) print_help; ;;
	-t) NEED_TEST=true; shift; ;;
	-v) VERBOSE=true; shift; ;;
	--) shift; ;;
	*) break;;
	esac
done

if [ true == "$VERBOSE" ] ; then
	export BASH_X="-x"
fi

# Testing script
if [ true == "$NEED_TEST" ] ; then
	export script=$(cat <<END
		rm -f /tmp/pid.\$$.finished

		( $@ ) &> /tmp/pid.\$$.finished

		touch /tmp/pid.\$$.finished

		while true 
		do 
			: 
		done
END
	)
else
	export script=$(cat <<END
		$@
END
	)
fi

export inner_one=$(cat <<END
	sleep 1
	( $script ) &>/dev/null
END
)

# Script wrapper
if [ true == "$NEED_TEST" ] ; then
	export outer_one=$(cat <<END
		nohup bash $BASH_X -c '$inner_one' &>/dev/null & 
		echo \$! > $pid_file
		ps auxf
		kill -9 \$$
END
	)
else
	export outer_one=$(cat <<END
		nohup bash $BASH_X -c '$inner_one' &>/dev/null & 
		kill -9 \$$
END
	)
fi

if [ true == "$VERBOSE" ] ; then
	echo "Whole script to be run:"
	echo bash $BASH_X -c "$outer_one"
fi

# bash instance to be killed and to make children process an orphan
if [ true == "$NEED_TEST" ] ; then
	bash $BASH_X -c "$outer_one" &

	sleep 2

	#
	# Simple test to be sure, that script is working
	#
	kill -0 $(cat $pid_file)

	if [ 0 -eq $? ] ; then
		echo script is working
	else
		echo script is failed
	fi
else
	bash $BASH_X -c "$outer_one"
fi

