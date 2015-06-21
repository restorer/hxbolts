#!/bin/bash

pushd `dirname "$0"`

[ -e hxbolts.zip ] && rm hxbolts.zip
[ -e tests/build ] && rm -r tests/build
[ -e tests/report ] && rm -r tests/report
[ -e demos/01-basic/demo.swf ] && rm demos/01-basic/demo.swf
[ -e demos/02-threads-openfl/export ] && rm -r demos/02-threads-openfl/export

zip -r -9 hxbolts.zip * -x submit-to-haxelib.sh

[ -e hxbolts.zip ] && haxelib submit hxbolts.zip
[ -e hxbolts.zip ] && rm hxbolts.zip

popd
