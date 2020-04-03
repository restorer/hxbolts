#!/bin/bash

cd $(dirname "$0")
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

if [ "$BRANCH" == "HEAD" ] ; then
    echo "Publishing is not allowed from \"detached HEAD\""
    echo "Switch to \"master\", \"develop\" or other valid branch and retry"
    exit
fi

if [ "$(git status -s)" != "" ] ; then
    echo "Seems that you have uncommitted changes. Commit and push first, than publish."
    git status -s
    exit
fi

if [ "$(git log --format=format:%H origin/${BRANCH}..${BRANCH})" != "" ] ; then
    echo "Seems that you have unpushed changes. Pull/push first, than publish."
    git log --format=format:"%C(auto)%H %C(green)%an%C(reset) %s" "origin/${BRANCH}..${BRANCH}"
    exit
fi

VERSION="$(cat "./haxelib.json" | grep -e '^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"[0-9.]*"[[:space:]]*,[[:space:]]*$' | sed 's/[^0-9.]//g')"
ESCAPED_VERSION="$(echo "$VERSION" | sed 's/\./\\./g')"
HAS_TAG="$(git tag | grep -e "^v${ESCAPED_VERSION}$")"

if [ "$HAS_TAG" != "" ] ; then
    if [ "$1" == "--retag" ] || [ "$2" == "--retag" ] ; then
        git tag -d "v${VERSION}"
        git push origin ":v${VERSION}"
    else
        echo "Git tag v${VERSION} already exists. If you want to recreate tag, use:"
        echo "$0 --retag"
        exit
    fi
fi

[ -e hxbolts.zip ] && rm hxbolts.zip
[ -e tests/build ] && rm -r tests/build
[ -e tests/report ] && rm -r tests/report
[ -e demos/01-basic/demo.swf ] && rm demos/01-basic/demo.swf
[ -e demos/02-threads-openfl/export ] && rm -r demos/02-threads-openfl/export
[ -e demos/03-lime/export ] && rm -r demos/03-lime/export

zip -r -9 hxbolts.zip * -x publish-release.sh -x unit-test.sh

if [ "$1" == "--dry-run" ] || [ "$2" == "--dry-run" ] ; then
    exit
fi

echo "Tagging v${VERSION} ..."
git tag "v${VERSION}" && git push --tags

echo "Submitting to haxelib ..."
[ -e hxbolts.zip ] && haxelib submit hxbolts.zip
[ -e hxbolts.zip ] && rm hxbolts.zip
