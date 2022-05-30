@import Darwin;
#include <Hypervisor/Hypervisor.h>

const char kVMCode[] = {
    // Compute ((2 + 2) - 1)
    0x40, 0x00, 0x80, 0xD2,  // mov x0, #2
    0x00, 0x08, 0x00, 0x91,  // add x0, x0, #2
    0x00, 0x04, 0x00, 0xD1,  // sub x0, x0, #1
    // Write it to memory pointed by x1
    0x20, 0x00, 0x00, 0xF9,  // str x0, [x1]
    // Reboot the computer with PSCI/SMCCC
    // 0x84000009 is PSCI SYSTEM_RESET using SMC32 calling convention
    0x20, 0x01, 0x80, 0xd2,  // mov x0, 0x0009
    0x00, 0x80, 0xb0, 0xf2,  // movk x0, 0x8400, lsl #16
    0x02, 0x00, 0x00, 0xD4,  // hvc #0
    // Infinite loop
    0x00, 0x00, 0x00, 0x14,  // b .
};

int main() {
  // https://github.com/zhuowei/FakeHVF/blob/main/simplevm.c
  // https://gist.github.com/imbushuo/51b09e61ecd7b7ac063853ad65cedf34
  // allocate 1MB of RAM, aligned to page size, for the VM
  const uint64_t kMemSize = 0x100000;
  const uint64_t kMemStart = 0x69420000;
  const uint64_t kMemResultOutOffset = 0x100;
  const uint64_t kMemGuestResultOut = kMemStart + kMemResultOutOffset;

  char* vm_ram = mmap(NULL, kMemSize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (vm_ram == MAP_FAILED) {
    abort();
  }
  // copy our code into the VM's RAM
  memcpy(vm_ram, kVMCode, sizeof(kVMCode));

  hv_return_t err = hv_vm_create(nil);
  printf("vm create %x\n", err);

  err = hv_vm_map(vm_ram, kMemStart, kMemSize, HV_MEMORY_READ | HV_MEMORY_WRITE | HV_MEMORY_EXEC);
  printf("hv_vm_map %x\n", err);

  hv_vcpu_t vcpu = 0;
  hv_vcpu_exit_t* exit = nil;
  err = hv_vcpu_create(&vcpu, &exit, nil);
  printf("vcpu create %x\n", err);

  // Set the CPU's PC to execute code from our RAM
  err = hv_vcpu_set_reg(vcpu, HV_REG_PC, kMemStart);
  printf("vcpu set reg pc %x\n", err);
  // Set CPU's x1 register to point to where we want to read the result
  err = hv_vcpu_set_reg(vcpu, HV_REG_X1, kMemGuestResultOut);
  printf("vcpu set reg x1 %x\n", err);
  // Set CPU's CPSR to EL1
  err = hv_vcpu_set_reg(vcpu, HV_REG_CPSR, 0x3c4);
  printf("vcpu set reg cpsr %x\n", err);

  err = hv_vcpu_run(vcpu);
  printf("run %x\n", err);

  uint64_t result_out = *((uint64_t*)(vm_ram + kMemResultOutOffset));
  printf("The result of (2 + 2) - 1 is %d\n", (int)result_out);
}
