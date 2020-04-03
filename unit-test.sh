#!/bin/bash

cd $(dirname "$0")/tests
NOSTRIP="$(cat "./test.hxml" | grep -e '-D [ ]*nostrip')"

# "strip" in the latest macOS is incompatible with hxcpp
if [ "$NOSTRIP" = "" ] ; then
    sed -i.bak '/-cpp /i\
-D nostrip\
' test.hxml
fi

haxelib run munit test
