// Decompiled by hand (based-ish on a Ghidra decompile) from Hypervisor.framework on macOS 12.0b1
@import Darwin;
#include <Hypervisor/Hypervisor.h>
#include <assert.h>
#include "hv_kernel_structs.h"

#if NO_HVF_HEADER
@protocol OS_hv_vcpu_config;
@class NSObject;

typedef kern_return_t hv_return_t;
typedef void* hv_vm_config_t;
typedef uint64_t hv_ipa_t;
typedef uint64_t hv_vcpu_t;
typedef uint64_t hv_exception_syndrome_t;
typedef uint64_t hv_exception_address_t;
typedef uint64_t hv_exit_reason_t;
typedef NSObject<OS_hv_vcpu_config>* hv_vcpu_config_t;
typedef uint64_t hv_memory_flags_t;
#define HV_BAD_ARGUMENT 0xfae94003;
#define HV_UNSUPPORTED 0xfae9400f;

// from hv_vcpu_types.h

typedef struct hv_vcpu_exit_exception {
  hv_exception_syndrome_t syndrome;
  hv_exception_address_t virtual_address;
  hv_ipa_t physical_address;
} hv_vcpu_exit_exception_t;

typedef struct hv_vcpu_exit {
  hv_exit_reason_t reason;
  hv_vcpu_exit_exception_t exception;
} hv_vcpu_exit_t;
#endif  // NO_HVF_HEADER

static_assert(sizeof(hv_vcpu_exit_t) == 0x20, "hv_vcpu_exit");

#define HV_CALL_VM_GET_CAPABILITIES 0
#define HV_CALL_VM_CREATE 1
#define HV_CALL_VM_DESTROY 2
#define HV_CALL_VM_MAP 3
#define HV_CALL_VM_UNMAP 4
#define HV_CALL_VM_PROTECT 5
#define HV_CALL_VCPU_CREATE 6
#define HV_CALL_VCPU_DESTROY 7
#define HV_CALL_VCPU_SYSREGS_SYNC 8
#define HV_CALL_VCPU_RUN 9
#define HV_CALL_VCPU_RUN_CANCEL 10
#define HV_CALL_VCPU_SET_ADDRESS_SPACE 11
#define HV_CALL_VM_ADDRESS_SPACE_CREATE 12
#define HV_CALL_VM_INVALIDATE_TLB 13

#ifdef USE_EXTERNAL_HV_TRAP
uint64_t hv_trap(unsigned int hv_call, void* hv_arg);
#else
__attribute__((naked)) uint64_t hv_trap(unsigned int hv_call, void* hv_arg) {
  asm volatile("mov x16, #-0x5\n"
               "svc 0x80\n"
               "ret\n");
}
#endif

// type lookup hv_vm_create_t
struct hv_vm_create_kernel_args {
  uint64_t min_ipa;
  uint64_t ipa_size;
  uint32_t granule;
  uint32_t flags;
  uint32_t isa;
};
static_assert(sizeof(struct hv_vm_create_kernel_args) == 0x20, "hv_vm_create_kernel_args size");

const struct hv_vm_create_kernel_args kDefaultVmCreateKernelArgs = {
    .min_ipa = 0,
    .ipa_size = 0,
    .granule = 0,
    .flags = 0,
    .isa = 1,
};

hv_return_t hv_vm_create(hv_vm_config_t config) {
  struct hv_vm_create_kernel_args args = kDefaultVmCreateKernelArgs;
  if (config) {
    // TODO(zhuowei): figure this out?
  }
  return hv_trap(HV_CALL_VM_CREATE, &args);
}

// type lookup hv_vm_map_item_t, although fields are renamed to match userspace args
struct hv_vm_map_kernel_args {
  void* addr;               // 0x0
  hv_ipa_t ipa;             // 0x8
  size_t size;              // 0x10
  hv_memory_flags_t flags;  // 0x18
  uint64_t asid;            // 0x20
};

hv_return_t hv_vm_map(void* addr, hv_ipa_t ipa, size_t size, hv_memory_flags_t flags) {
  struct hv_vm_map_kernel_args args = {
      .addr = addr, .ipa = ipa, .size = size, .flags = flags, .asid = 0};
  return hv_trap(HV_CALL_VM_MAP, &args);
}

static pthread_mutex_t vcpus_mutex = PTHREAD_MUTEX_INITIALIZER;

struct hv_vcpu_zone {
  arm_guest_rw_context_t rw;
  arm_guest_ro_context_t ro;
};

static_assert(sizeof(struct hv_vcpu_zone) == 0x8000, "hv_vcpu_zone");

struct hv_vcpu_data {
  struct hv_vcpu_zone* vcpu_zone;  // 0x0
  // TODO(zhuowei)
  char filler[0xf0 - 0x8];  // 0x8
  hv_vcpu_exit_t exit;      // 0xf0
  char filler2[0x8];        // 0x110
};

static_assert(sizeof(struct hv_vcpu_data) == 0x118, "hv_vcpu_data");

static const size_t kHvMaxVcpus = 0x40;
static struct hv_vcpu_data vcpus[kHvMaxVcpus];

struct hv_vcpu_create_kernel_args {
  uint64_t id;                            // 0x0
  struct hv_vcpu_zone* output_vcpu_zone;  // 0x8
};

// ' hyp', 0xe
static const uint64_t kHvVcpuMagic = 0x206879700000000eull;

hv_return_t hv_vcpu_create(hv_vcpu_t* vcpu, hv_vcpu_exit_t** exit, hv_vcpu_config_t config) {
  pthread_mutex_lock(&vcpus_mutex);
  hv_vcpu_t cpuid = 0;
  for (; cpuid < kHvMaxVcpus; cpuid++) {
    if (!vcpus[cpuid].vcpu_zone) {
      break;
    }
  }
  if (cpuid == kHvMaxVcpus) {
    pthread_mutex_unlock(&vcpus_mutex);
    return HV_NO_RESOURCES;
  }
  // TODO(zhuowei): support more than one
  struct hv_vcpu_data* vcpu_data = &vcpus[cpuid];
  struct hv_vcpu_create_kernel_args args = {
      .id = cpuid,
      .output_vcpu_zone = 0,
  };
  kern_return_t err = hv_trap(HV_CALL_VCPU_CREATE, &args);
  if (err) {
    pthread_mutex_unlock(&vcpus_mutex);
    return err;
  }
  printf("vcpu_zone = %p\n", args.output_vcpu_zone);
  if (args.output_vcpu_zone->ro.ver != kHvVcpuMagic) {
    printf("Invalid magic! expected %llx, got %llx\n", kHvVcpuMagic, args.output_vcpu_zone->ro.ver);
    const bool yolo = true;
    if (!yolo) {
      hv_trap(HV_CALL_VCPU_DESTROY, nil);
      pthread_mutex_unlock(&vcpus_mutex);
      return HV_UNSUPPORTED;
    }
    printf("yoloing\n");
  }
  vcpu_data->vcpu_zone = args.output_vcpu_zone;
  *vcpu = cpuid;  // TODO(zhuowei)
  *exit = &vcpu_data->exit;
  pthread_mutex_unlock(&vcpus_mutex);
  // TODO(zhuowei): configure regs
  return 0;
}

hv_return_t hv_vcpu_run(hv_vcpu_t vcpu) {
  // TODO(zhuowei): update registers
  struct hv_vcpu_data* vcpu_data = &vcpus[0];
  hv_return_t err = hv_trap(HV_CALL_VCPU_RUN, nil);
  if (err) {
    return err;
  }
  printf("exit = %d (esr = %x)\n", vcpu_data->vcpu_zone->ro.exit.vmexit_reason,
         vcpu_data->vcpu_zone->ro.exit.vmexit_esr);
  return 0;
}

hv_return_t hv_vcpu_get_reg(hv_vcpu_t vcpu, hv_reg_t reg, uint64_t* value) {
  if (reg > HV_REG_CPSR) {
    return HV_BAD_ARGUMENT;
  }
  struct hv_vcpu_zone* vcpu_zone = vcpus[vcpu].vcpu_zone;
  if (reg < HV_REG_FP) {
    *value = vcpu_zone->rw.regs.x[reg];
  } else if (reg == HV_REG_FP) {
    *value = vcpu_zone->rw.regs.fp;
  } else if (reg == HV_REG_LR) {
    *value = vcpu_zone->rw.regs.lr;
  } else if (reg == HV_REG_PC) {
    *value = vcpu_zone->rw.regs.pc;
  } else if (reg == HV_REG_FPCR) {
    *value = vcpu_zone->rw.neon.fpcr;
  } else if (reg == HV_REG_FPSR) {
    *value = vcpu_zone->rw.neon.fpsr;
  } else if (reg == HV_REG_CPSR) {
    *value = vcpu_zone->rw.regs.cpsr;
  }
  return 0;
}

hv_return_t hv_vcpu_set_reg(hv_vcpu_t vcpu, hv_reg_t reg, uint64_t value) {
  if (reg > HV_REG_CPSR) {
    return HV_BAD_ARGUMENT;
  }
  struct hv_vcpu_zone* vcpu_zone = vcpus[vcpu].vcpu_zone;
  if (reg < HV_REG_FP) {
    vcpu_zone->rw.regs.x[reg] = value;
  } else if (reg == HV_REG_FP) {
    vcpu_zone->rw.regs.lr = value;
  } else if (reg == HV_REG_LR) {
    vcpu_zone->rw.regs.lr = value;
  } else if (reg == HV_REG_PC) {
    vcpu_zone->rw.regs.pc = value;
  } else if (reg == HV_REG_FPCR) {
    vcpu_zone->rw.neon.fpcr = value;
  } else if (reg == HV_REG_FPSR) {
    vcpu_zone->rw.neon.fpsr = value;
  } else if (reg == HV_REG_CPSR) {
    vcpu_zone->rw.regs.cpsr = value;
  }
  return 0;
}

hv_return_t hv_vcpu_get_simd_fp_reg(hv_vcpu_t vcpu, hv_simd_fp_reg_t reg,
                                    hv_simd_fp_uchar16_t* value) {
  if (reg > HV_SIMD_FP_REG_Q31) {
    return HV_BAD_ARGUMENT;
  }
  struct hv_vcpu_zone* vcpu_zone = vcpus[vcpu].vcpu_zone;
  *((__uint128_t*)value) = vcpu_zone->rw.neon.q[reg];
  return 0;
}

hv_return_t hv_vcpu_set_simd_fp_reg(hv_vcpu_t vcpu, hv_simd_fp_reg_t reg,
                                    hv_simd_fp_uchar16_t value) {
  if (reg > HV_SIMD_FP_REG_Q31) {
    return HV_BAD_ARGUMENT;
  }
  struct hv_vcpu_zone* vcpu_zone = vcpus[vcpu].vcpu_zone;
  vcpu_zone->rw.neon.q[reg] = *((__uint128_t*)&value);
  return 0;
}

static bool find_sys_reg(hv_sys_reg_t sys_reg, uint64_t* offset, uint64_t* sync_mask) {
  uint64_t o = 0;
  uint64_t f = 0;
  switch (sys_reg) {
#include "sysreg_offsets.h"
    default:
      return false;
  }
  *offset = o;
  *sync_mask = f;
  return true;
}

static_assert(offsetof(arm_guest_rw_context_t, dbgregs.bp[0].bvr) == 0x450,
              "HV_SYS_REG_DBGBVR0_EL1");

hv_return_t hv_vcpu_get_sys_reg(hv_vcpu_t vcpu, hv_sys_reg_t sys_reg, uint64_t *value) {
  if (sys_reg >= HV_SYS_REG_ID_AA64ISAR0_EL1 && sys_reg <= HV_SYS_REG_ID_AA64MMFR2_EL1) {
    printf("TODO(zhuowei): not implemented\n");
    return HV_BAD_ARGUMENT;
  }
  // TODO(zhuowei): handle the special cases
  uint64_t offset = 0;
  uint64_t sync_mask = 0;
  bool found = find_sys_reg(sys_reg, &offset, &sync_mask);
  if (!found) {
    return HV_BAD_ARGUMENT;
  }
  if (sync_mask) {
    // TODO(zhuowei): HV_CALL_VCPU_SYSREGS_SYNC only when needed
    hv_trap(HV_CALL_VCPU_SYSREGS_SYNC, 0);
  }
  struct hv_vcpu_zone* vcpu_zone = vcpus[vcpu].vcpu_zone;
  *value = *(uint64_t*)((char*)(&vcpu_zone->rw) + offset);
  return 0;
}


hv_return_t hv_vcpu_set_sys_reg(hv_vcpu_t vcpu, hv_sys_reg_t sys_reg, uint64_t value) {
  if (sys_reg >= HV_SYS_REG_ID_AA64ISAR0_EL1 && sys_reg <= HV_SYS_REG_ID_AA64MMFR2_EL1) {
    printf("TODO(zhuowei): not implemented\n");
    return HV_BAD_ARGUMENT;
  }
  // TODO(zhuowei): handle the special cases
  uint64_t offset = 0;
  uint64_t sync_mask = 0;
  bool found = find_sys_reg(sys_reg, &offset, &sync_mask);
  if (!found) {
    return HV_BAD_ARGUMENT;
  }
  if (sync_mask) {
    // TODO(zhuowei): HV_CALL_VCPU_SYSREGS_SYNC only when needed
    hv_trap(HV_CALL_VCPU_SYSREGS_SYNC, 0);
  }
  struct hv_vcpu_zone* vcpu_zone = vcpus[vcpu].vcpu_zone;
  *(uint64_t*)((char*)(&vcpu_zone->rw) + offset) = offset;
  return 0;
}

hv_return_t hv_vcpus_exit(hv_vcpu_t* vcpus, uint32_t vcpu_count) {
  uint64_t mask = 0;
  for (int i = 0; i < vcpu_count; i++) {
    hv_vcpu_t cpu = vcpus[i];
    if (cpu >= kHvMaxVcpus) {
      return HV_BAD_ARGUMENT;
    }
    mask |= (1ul << cpu);
  }
  return hv_trap(HV_CALL_VCPU_RUN_CANCEL, (void*)mask);
}
