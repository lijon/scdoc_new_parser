#!/bin/sh

for F in `find $1 -name '*.schelp' -not -name '*.ext.schelp'`; do
#echo -n "$F: "
#if (parser $F 2>&1 1>/dev/null); then
#    echo OK
#fi
parser $F 2>&1 1>/dev/null
done

