#!/bin/sh
set -e
macospath="$(xcrun --sdk macosx --show-sdk-path)"
rm -r fixed_hv_headers || true
mkdir -p fixed_hv_headers/Hypervisor
for i in "$macospath/System/Library/Frameworks/Hypervisor.framework/Headers/"*
do
	echo $i
	sed -e "s/API_UNAVAILABLE(ios)/API_AVAILABLE(ios(14.0))/g" "$i" >fixed_hv_headers/Hypervisor/$(basename "$i")
done
