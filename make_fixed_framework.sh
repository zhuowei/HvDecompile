#!/bin/sh
set -e
macospath="$(xcrun --sdk macosx --show-sdk-path)"
rm -r fixed_framework || true
mkdir fixed_framework
cp -a "$macospath/System/Library/Frameworks/Hypervisor.framework" fixed_framework/
for i in "$macospath/System/Library/Frameworks/Hypervisor.framework/Headers/"*
do
	echo $i
	sed -e "s/API_UNAVAILABLE(ios)/API_AVAILABLE(ios(14.0))/g" "$i" >"fixed_framework/Hypervisor.framework/Headers/$(basename "$i")"
done
sed -i "" \
	-e "s@/System/Library/Frameworks/Hypervisor.framework/Versions/A/Hypervisor@/usr/local/zhuowei/Hypervisor@" \
	-e "s/-macos/-ios/g" \
	fixed_framework/Hypervisor.framework/Versions/A/Hypervisor.tbd
