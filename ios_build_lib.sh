#!/bin/sh
set -e
xcrun -sdk iphoneos clang -fmodules -Os -g -target arm64-apple-ios14 -o Hypervisor -shared \
	-DUSE_EXTERNAL_HV_TRAP -DOLDSTRUCT_IOS141 -Ifixed_hv_headers -framework IOKit \
	hv.m userclient_hv_trap.m
codesign --sign - --force Hypervisor
