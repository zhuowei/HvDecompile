#!/bin/sh
set -e
clang -fmodules -Os -g -target arm64-apple-macos12 -o hv hv.m hv_demo.m
codesign --sign - --force --entitlements hv.entitlements hv
