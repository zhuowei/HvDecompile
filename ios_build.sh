#!/bin/sh
set -e
macospath="$(xcrun --sdk macosx --show-sdk-path)"
xcrun -sdk iphoneos clang -fmodules -Os -g -target arm64-apple-ios14 -o ios_hv \
	-DUSE_EXTERNAL_HV_TRAP -Ifixed_hv_headers -framework IOKit \
	hv.m userclient_hv_trap.m 
codesign --sign - --force --entitlements ios_hv.entitlements ios_hv
