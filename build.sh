#!/bin/bash
set -xe

[ -d build ] || git clone https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools build
./build/build.sh "$@"
