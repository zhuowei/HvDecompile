// Decompiled by hand (based-ish on a Ghidra decompile) from Hypervisor.framework on macOS 12.0b1
@import Darwin;
#include <Hypervisor/Hypervisor.h>
#include <assert.h>
#include "hv_kernel_structs.h"

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

static uint64_t hv_trap_wrap(unsigned int hv_call, void* hv_arg) {
  uint64_t err = hv_trap(hv_call, hv_arg);
  printf("hv_trap %u %p returned %llx\n", hv_call, hv_arg, err);
  return err;
}
//#define hv_trap hv_trap_wrap

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

hv_return_t hv_vm_unmap(hv_ipa_t ipa, size_t size) {
  struct hv_vm_map_kernel_args args = {
      .addr = nil, .ipa = ipa, .size = size, .flags = 0, .asid = 0};
  return hv_trap(HV_CALL_VM_UNMAP, &args);
}

hv_return_t hv_vm_protect(hv_ipa_t ipa, size_t size, hv_memory_flags_t flags) {
  struct hv_vm_map_kernel_args args = {
      .addr = nil, .ipa = ipa, .size = size, .flags = flags, .asid = 0};
  return hv_trap(HV_CALL_VM_PROTECT, &args);
}

static pthread_mutex_t vcpus_mutex = PTHREAD_MUTEX_INITIALIZER;

struct hv_vcpu_zone {
  arm_guest_rw_context_t rw;
  arm_guest_ro_context_t ro;
};

static_assert(sizeof(struct hv_vcpu_zone) == 0x8000, "hv_vcpu_zone");

struct hv_vcpu_data {
  struct hv_vcpu_zone* vcpu_zone;  // 0x0
  uint64_t aa64dfr0_el1;           // 0x8
  uint64_t aa64dfr1_el1;           // 0x10
  uint64_t aa64isar0_el1;          // 0x18
  uint64_t aa64isar1_el1;          // 0x20
  uint64_t aa64mmfr0_el1;          // 0x28
  uint64_t aa64mmfr1_el1;          // 0x30
  uint64_t aa64mmfr2_el1;          // 0x38
  uint64_t aa64pfr0_el1;           // 0x40
  uint64_t aa64pfr1_el1;           // 0x48
  char filler[0xe8 - 0x50];        // 0x50
  uint64_t pending_interrupts;     // 0xe8
  hv_vcpu_exit_t exit;             // 0xf0
  char filler2[0x8];               // 0x110
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

hv_return_t hv_vcpu_destroy(hv_vcpu_t vcpu) {
  kern_return_t err = hv_trap(HV_CALL_VCPU_DESTROY, nil);
  if (err) {
    return err;
  }
  pthread_mutex_lock(&vcpus_mutex);
  struct hv_vcpu_data* vcpu_data = &vcpus[vcpu];
  vcpu_data->vcpu_zone = nil;
  // TODO(zhuowei): vcpu + 0xe8 = 0???
  vcpu_data->pending_interrupts = 0;
  pthread_mutex_unlock(&vcpus_mutex);
  return 0;
}

hv_return_t hv_vcpu_run(hv_vcpu_t vcpu) {
  // TODO(zhuowei): update registers
  struct hv_vcpu_data* vcpu_data = &vcpus[0];
  bool injected_interrupt = false;
  if (vcpu_data->pending_interrupts) {
    injected_interrupt = true;
    vcpu_data->vcpu_zone->rw.controls.hcr_el2 |= vcpu_data->pending_interrupts;
    vcpu_data->vcpu_zone->rw.state_dirty |= 0x4;
  }
  while (true) {
    hv_return_t err = hv_trap(HV_CALL_VCPU_RUN, nil);
    if (err) {
      return err;
    }
    bool print_vmexit = false;
    if (print_vmexit) {
      printf("exit = %d (esr = %x far = %llx hpfar = %llx)\n",
             vcpu_data->vcpu_zone->ro.exit.vmexit_reason, vcpu_data->vcpu_zone->ro.exit.vmexit_esr,
             vcpu_data->vcpu_zone->ro.exit.vmexit_far, vcpu_data->vcpu_zone->ro.exit.vmexit_hpfar);
    }
    hv_vcpu_exit_t* exit = &vcpu_data->exit;
    switch (vcpu_data->vcpu_zone->ro.exit.vmexit_reason) {
      case 0: {
        exit->reason = HV_EXIT_REASON_CANCELED;
        break;
      }
      case 1:  // hvc call?
      case 6:  // memory fault?
      case 8: {
        exit->reason = HV_EXIT_REASON_EXCEPTION;
        exit->exception.syndrome = vcpu_data->vcpu_zone->ro.exit.vmexit_esr;
        exit->exception.virtual_address = vcpu_data->vcpu_zone->ro.exit.vmexit_far;
        exit->exception.physical_address = vcpu_data->vcpu_zone->ro.exit.vmexit_hpfar;
        // TODO(zhuowei): handle registers
        break;
      }
      case 3:
      case 4: {
        // if (vcpu_data->vcpu_zone->rw.banked.cntv_ctl_el0 == 5 &&
        exit->reason = HV_EXIT_REASON_VTIMER_ACTIVATED;
        // mask vtimer
        vcpu_data->vcpu_zone->rw.controls.timer |= 1ull;
        break;
      }
      case 2:
      case 11: {
        // keep going!
        continue;
      }
      default: {
        exit->reason = HV_EXIT_REASON_UNKNOWN;
        break;
      }
    }
    if (injected_interrupt) {
      vcpu_data->pending_interrupts = 0;
      vcpu_data->vcpu_zone->rw.controls.hcr_el2 &= ~0xc0ull;
      vcpu_data->vcpu_zone->rw.state_dirty |= 0x4;
    }
    return 0;
  }
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

//static_assert(offsetof(arm_guest_rw_context_t, dbgregs.bp[0].bvr) == 0x450,
//              "HV_SYS_REG_DBGBVR0_EL1");

hv_return_t hv_vcpu_get_sys_reg(hv_vcpu_t vcpu, hv_sys_reg_t sys_reg, uint64_t* value) {
  struct hv_vcpu_data* vcpu_data = &vcpus[vcpu];
  struct hv_vcpu_zone* vcpu_zone = vcpu_data->vcpu_zone;
  switch (sys_reg) {
    case HV_SYS_REG_MIDR_EL1:
      *value = vcpu_zone->rw.controls.vpidr_el2;
      return 0;
    case HV_SYS_REG_MPIDR_EL1:
      *value = vcpu_zone->rw.controls.vmpidr_el2;
      return 0;
    case HV_SYS_REG_ID_AA64PFR0_EL1:
      *value = vcpu_data->aa64pfr0_el1;
      return 0;
    case HV_SYS_REG_ID_AA64PFR1_EL1:
      *value = vcpu_data->aa64pfr1_el1;
      return 0;
    case HV_SYS_REG_ID_AA64DFR0_EL1:
      *value = vcpu_data->aa64dfr0_el1;
      return 0;
    case HV_SYS_REG_ID_AA64DFR1_EL1:
      *value = vcpu_data->aa64dfr1_el1;
      return 0;
    case HV_SYS_REG_ID_AA64ISAR0_EL1:
      *value = vcpu_data->aa64isar0_el1;
      return 0;
    case HV_SYS_REG_ID_AA64ISAR1_EL1:
      *value = vcpu_data->aa64isar1_el1;
      return 0;
    case HV_SYS_REG_ID_AA64MMFR0_EL1:
      *value = vcpu_data->aa64mmfr0_el1;
      return 0;
    case HV_SYS_REG_ID_AA64MMFR1_EL1:
      *value = vcpu_data->aa64mmfr1_el1;
      return 0;
    case HV_SYS_REG_ID_AA64MMFR2_EL1:
      *value = vcpu_data->aa64mmfr2_el1;
      return 0;
    default:
      break;
  }
  // TODO(zhuowei): handle the special cases
  uint64_t offset = 0;
  uint64_t sync_mask = 0;
  bool found = find_sys_reg(sys_reg, &offset, &sync_mask);
  if (!found) {
    printf("invalid get sys reg: %x\n", sys_reg);
    return HV_BAD_ARGUMENT;
  }
  if (sync_mask) {
    // TODO(zhuowei): HV_CALL_VCPU_SYSREGS_SYNC only when needed
    hv_trap(HV_CALL_VCPU_SYSREGS_SYNC, 0);
  }
  *value = *(uint64_t*)((char*)(&vcpu_zone->rw) + offset);
  return 0;
}

hv_return_t hv_vcpu_set_sys_reg(hv_vcpu_t vcpu, hv_sys_reg_t sys_reg, uint64_t value) {
  struct hv_vcpu_data* vcpu_data = &vcpus[vcpu];
  struct hv_vcpu_zone* vcpu_zone = vcpu_data->vcpu_zone;
  switch (sys_reg) {
    case HV_SYS_REG_MIDR_EL1: {
      vcpu_zone->rw.controls.vpidr_el2 = value;
      vcpu_zone->rw.state_dirty |= 0x4;
      return 0;
    }
    case HV_SYS_REG_MPIDR_EL1: {
      vcpu_zone->rw.controls.vmpidr_el2 = value;
      vcpu_zone->rw.state_dirty |= 0x4;
      return 0;
    }
      // the kernel doesn't set these - userspace traps and handles these
    case HV_SYS_REG_ID_AA64PFR0_EL1:
      vcpu_data->aa64pfr0_el1 = value;
      return 0;
    case HV_SYS_REG_ID_AA64PFR1_EL1:
      vcpu_data->aa64pfr1_el1 = value;
      return 0;
    case HV_SYS_REG_ID_AA64DFR0_EL1:
      vcpu_data->aa64dfr0_el1 = value;
      return 0;
    case HV_SYS_REG_ID_AA64DFR1_EL1:
      vcpu_data->aa64dfr1_el1 = value;
      return 0;
    case HV_SYS_REG_ID_AA64ISAR0_EL1:
      vcpu_data->aa64isar0_el1 = value;
      return 0;
    case HV_SYS_REG_ID_AA64ISAR1_EL1:
      vcpu_data->aa64isar1_el1 = value;
      return 0;
    case HV_SYS_REG_ID_AA64MMFR0_EL1:
      vcpu_data->aa64mmfr0_el1 = value;
      return 0;
    case HV_SYS_REG_ID_AA64MMFR1_EL1:
      vcpu_data->aa64mmfr1_el1 = value;
      return 0;
    case HV_SYS_REG_ID_AA64MMFR2_EL1:
      vcpu_data->aa64mmfr2_el1 = value;
      return 0;
    default:
      break;
  }
  // TODO(zhuowei): handle the special cases
  uint64_t offset = 0;
  uint64_t sync_mask = 0;
  bool found = find_sys_reg(sys_reg, &offset, &sync_mask);
  if (!found) {
    printf("invalid set sys reg: %x\n", sys_reg);
    return HV_BAD_ARGUMENT;
  }
  if (sync_mask) {
    // TODO(zhuowei): HV_CALL_VCPU_SYSREGS_SYNC only when needed
    hv_trap(HV_CALL_VCPU_SYSREGS_SYNC, 0);
    vcpu_zone->rw.state_dirty |= sync_mask;
  }
  *(uint64_t*)((char*)(&vcpu_zone->rw) + offset) = value;
  return 0;
}

hv_return_t hv_vcpu_get_vtimer_mask(hv_vcpu_t vcpu, bool* vtimer_is_masked) {
  if (!vtimer_is_masked) {
    return HV_BAD_ARGUMENT;
  }
  struct hv_vcpu_zone* vcpu_zone = vcpus[vcpu].vcpu_zone;
  *vtimer_is_masked = vcpu_zone->rw.controls.timer & 1;
  return 0;
}

hv_return_t hv_vcpu_set_vtimer_mask(hv_vcpu_t vcpu, bool vtimer_is_masked) {
  struct hv_vcpu_zone* vcpu_zone = vcpus[vcpu].vcpu_zone;
  vcpu_zone->rw.controls.timer = (vcpu_zone->rw.controls.timer & ~1ull) | vtimer_is_masked;
  return 0;
}

hv_return_t hv_vcpu_get_vtimer_offset(hv_vcpu_t vcpu, uint64_t* vtimer_offset) {
  struct hv_vcpu_zone* vcpu_zone = vcpus[vcpu].vcpu_zone;
  *vtimer_offset = vcpu_zone->rw.controls.virtual_timer_offset;
  return 0;
}

hv_return_t hv_vcpu_set_vtimer_offset(hv_vcpu_t vcpu, uint64_t vtimer_offset) {
  struct hv_vcpu_zone* vcpu_zone = vcpus[vcpu].vcpu_zone;
  vcpu_zone->rw.controls.virtual_timer_offset = vtimer_offset;
  vcpu_zone->rw.state_dirty |= 0x4;
  return 0;
}

hv_return_t hv_vcpu_set_pending_interrupt(hv_vcpu_t vcpu, hv_interrupt_type_t type, bool pending) {
  struct hv_vcpu_data* vcpu_data = &vcpus[vcpu];
  if (type == HV_INTERRUPT_TYPE_IRQ) {
    // HCR_EL2 VI bit
    if (pending) {
      vcpu_data->pending_interrupts |= 0x80ull;
    } else {
      vcpu_data->pending_interrupts &= ~0x80ull;
    }
    return 0;
  } else if (type == HV_INTERRUPT_TYPE_FIQ) {
    // HCR_EL2 VF bit
    if (pending) {
      vcpu_data->pending_interrupts |= 0x40ull;
    } else {
      vcpu_data->pending_interrupts &= ~0x40ull;
    }
    return 0;
  } else {
    return HV_BAD_ARGUMENT;
  }
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
