@import Darwin;
@import Hypervisor;
int main() {
  // 12.3.1
  const uint64_t kHvVcpuGetSysRegAddr = 0x00000001e383f020ull;
  const uint64_t kFindSysRegAddr = 0x00000001e383f314ull;
  int64_t find_sys_reg_offset = kFindSysRegAddr - kHvVcpuGetSysRegAddr;
  uint64_t get_sys_reg_addr = (uint64_t)&hv_vcpu_get_sys_reg;
  bool (*find_sys_reg)(uint32_t reg, uint64_t * offset, uint64_t * flags) =
      (void*)(get_sys_reg_addr + find_sys_reg_offset);
  for (uint32_t reg = 0; reg < 0x10000; reg++) {
    uint64_t offset = 0;
    uint64_t flags = 0;
    bool found = find_sys_reg(reg, &offset, &flags);
    if (found) {
      printf("%x %llx %llx\n", reg, offset, flags);
    }
  }
}
