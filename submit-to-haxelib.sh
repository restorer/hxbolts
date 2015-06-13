#!/bin/bash

[ -e hxbolts.zip ] && rm hxbolts.zip
[ -x tests/build ] && rm -r tests/build
[ -x tests/report ] && rm -r tests/report
zip -r -9 hxbolts.zip * -x submit-to-haxelib.sh
[ -e hxbolts.zip ] && haxelib submit hxbolts.zip
[ -e hxbolts.zip ] && rm hxbolts.zip
