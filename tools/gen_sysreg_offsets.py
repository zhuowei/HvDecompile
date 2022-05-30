with open("sysreg_offsets.txt", "r") as infile:
    indata = [[int(part, 16) for part in line.split(" ")]
              for line in infile.read().strip().split("\n")]
hvheader = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Hypervisor.framework/Headers/hv_vcpu_types.h"
with open(hvheader, "r") as infile:
    headerlines = [
        line.strip().split("=") for line in infile.read().split("\n")
        if "HV_SYS_REG_" in line
    ]
headermap = dict([(int(a[1].rstrip(","), 16), a[0].strip())
                  for a in headerlines])
template = """case {}:
  o = {};
  f = {};
  break;
"""
outstr = ""
for entry in indata:
    regname = headermap[entry[0]]
    outstr += template.format(regname, hex(entry[1]), hex(entry[2]))
with open("../sysreg_offsets.h", "w") as outfile:
    outfile.write(outstr)
