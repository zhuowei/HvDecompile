// Decompiled by hand (based-ish on a Ghidra decompile) from Hypervisor.framework on macOS 12.0b1
@import Darwin;
#include <assert.h>

typedef uint64_t hv_return_t;
typedef void* hv_vm_config_t;

#define HV_CALL_VM_CREATE 1

__attribute__((naked)) uint64_t hv_trap(unsigned int hv_call, void* hv_arg) {
  asm volatile("mov x16, #-0x5\n"
               "svc 0x80\n"
               "ret\n");
}

struct hv_vm_create_kernel_args {
  uint64_t field_0;    // 0x0
  uint64_t field_8;    // 0x8
  int32_t field_10;    // 0x10
  uint32_t unused_14;  // 0x14
  int32_t field_18;    // 0x18
};
static_assert(sizeof(struct hv_vm_create_kernel_args) == 0x20, "hv_vm_create_kernel_args size");

const struct hv_vm_create_kernel_args kDefaultVmCreateKernelArgs = {
    .field_0 = 0,
    .field_8 = 0,
    .field_10 = 0,
    .unused_14 = 0,
    .field_18 = 1,
};

hv_return_t hv_vm_create(hv_vm_config_t config) {
  struct hv_vm_create_kernel_args args = kDefaultVmCreateKernelArgs;
  if (config) {
    // TODO(zhuowei): figure this out?
  }
  return hv_trap(HV_CALL_VM_CREATE, &args);
}

int main() {
  hv_return_t err = hv_vm_create(nil);
  printf("%llu\n", err);
}