#!/bin/sh

for F in `find $1 -name '*.schelp'`; do
echo -n "$F: "
if (parser $F 2>&1 1>/dev/null); then
    echo OK
fi
done

