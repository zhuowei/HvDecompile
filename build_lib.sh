#!/bin/sh
set -e
clang -fmodules -Os -g -target arm64-apple-macos12 -o Hypervisor -shared hv.m
codesign --sign - --force Hypervisor
