#pragma once
#include <Hypervisor/Hypervisor.h>

// Headers extracted from
// Kernel_Debug_Kit_12.5_build_21G5027d.dmg/kernel.release.t8101

// type lookup hv_vcpu_t
// type lookup arm_guest_context_t

typedef struct {
  uint64_t mdscr_el1;
  uint64_t tpidr_el1;
  uint64_t tpidr_el0;
  uint64_t tpidrro_el0;
  uint64_t sp_el0;
  uint64_t sp_el1;
  uint64_t par_el1;
  uint64_t csselr_el1;
  uint64_t apstate;
  uint64_t afpcr_el0;
} arm_guest_shared_sysregs_t;

typedef struct {
  uint64_t ttbr0_el1;
  uint64_t ttbr1_el1;
  uint64_t tcr_el1;
  uint64_t elr_el1;
  uint64_t far_el1;
  uint64_t esr_el1;
  uint64_t mair_el1;
  uint64_t amair_el1;
  uint64_t vbar_el1;
  uint64_t cntv_cval_el0;
  uint64_t cntp_cval_el0;
  uint64_t actlr_el1;
  uint64_t sctlr_el1;
  uint64_t cpacr_el1;
  uint64_t spsr_el1;
  uint64_t afsr0_el1;
  uint64_t afsr1_el1;
  uint64_t contextidr_el1;
  uint64_t cntv_ctl_el0;
  uint64_t cntp_ctl_el0;
  uint64_t cntkctl_el1;
  uint64_t ich_vmcr_el2;
} arm_guest_banked_sysregs_t;

typedef struct {
  uint64_t hcr_el2;
  uint64_t hacr_el2;
  uint64_t cptr_el2;
  uint64_t mdcr_el2;
  uint64_t vmpidr_el2;
  uint64_t vpidr_el2;
  uint64_t virtual_timer_offset;
  uint64_t hfgrtr_el2;
  uint64_t hfgwtr_el2;
  uint64_t hfgitr_el2;
  uint64_t hdfgrtr_el2;
  uint64_t hdfgwtr_el2;
  uint64_t cnthctl_el2;
  uint64_t timer;
  uint64_t vmkeyhi_el2;
  uint64_t vmkeylo_el2;
  uint64_t apsts_el1;
  uint64_t ich_hcr_el2;
  uint64_t ich_lr_el2[8];
  uint64_t host_debug;
} arm_guest_controls_t;

typedef struct {
  struct {
    uint64_t bvr;
    uint64_t bcr;
  } bp[16];
  struct {
    uint64_t wvr;
    uint64_t wcr;
  } wp[16];
  uint64_t mdccint_el1;
  uint64_t osdtrrx_el1;
  uint64_t osdtrtx_el1;
  uint8_t dbgclaim_el1;
} arm_guest_dbgregs_t;

typedef struct {
  uint64_t amx_state_t_el1;
  uint64_t amx_config_el1;
  uint64_t aspsr_el1;
  uint64_t ctrr_ctl_el1;
  uint64_t ctrr_a_lwr_el1;
  uint64_t ctrr_a_upr_el1;
  uint64_t ctrr_b_lwr_el1;
  uint64_t ctrr_b_upr_el1;
  uint64_t ctrr_lock_el1;
  uint64_t vmsa_lock_el1;
  uint64_t pmcr1_el1;
  uint64_t apctl_el1;
  uint64_t apgakeyhi_el1;
  uint64_t apgakeylo_el1;
  uint64_t apiakeyhi_el1;
  uint64_t apiakeylo_el1;
  uint64_t apibkeyhi_el1;
  uint64_t apibkeylo_el1;
  uint64_t apdakeyhi_el1;
  uint64_t apdakeylo_el1;
  uint64_t apdbkeyhi_el1;
  uint64_t apdbkeylo_el1;
  uint64_t kernkeyhi_el1;
  uint64_t kernkeylo_el1;
  uint64_t gxf_config_el1;
  uint64_t gxf_entry_el1;
  uint64_t gxf_pabentry_el1;
  uint64_t sp_gl1;
  uint64_t tpidr_gl1;
  uint64_t aspsr_gl1;
  uint64_t vbar_gl1;
  uint64_t far_gl1;
  uint64_t esr_gl1;
  uint64_t elr_gl1;
  uint64_t spsr_gl1;
  uint64_t pmcr1_gl1;
  uint64_t afsr1_gl1;
  uint64_t sprr_config_el1;
  uint64_t sprr_amrange_el1;
  uint64_t sprr_pperm_el1;
  uint64_t sprr_uperm_el0;
  uint64_t sprr_pmprr_el1;
  uint64_t sprr_umprr_el1;
  uint64_t sprr_pperm_sh1_el1;
  uint64_t sprr_pperm_sh2_el1;
  uint64_t sprr_pperm_sh3_el1;
  uint64_t sprr_pperm_sh4_el1;
  uint64_t sprr_pperm_sh5_el1;
  uint64_t sprr_pperm_sh6_el1;
  uint64_t sprr_pperm_sh7_el1;
  uint64_t sprr_uperm_sh1_el1;
  uint64_t sprr_uperm_sh2_el1;
  uint64_t sprr_uperm_sh3_el1;
  uint64_t sprr_uperm_sh4_el1;
  uint64_t sprr_uperm_sh5_el1;
  uint64_t sprr_uperm_sh6_el1;
  uint64_t sprr_uperm_sh7_el1;
  uint64_t acfg_el1;
  uint64_t jrange_el1;
  uint64_t jctl_el1;
  uint64_t japiakeyhi_el1;
  uint64_t japiakeylo_el1;
  uint64_t japibkeyhi_el1;
  uint64_t japibkeylo_el1;
} arm_guest_extregs_t;

typedef struct {
  uint8_t __res_00_20[32];
  uint64_t vttbr_el2;
  uint64_t __res_28;
  uint64_t vsttbr_el2;
  uint64_t __res_38;
  uint64_t vtcr_el2;
  uint64_t vstcr_el2;
  uint64_t vmpidr_el2;
  uint64_t __res_58;
  uint64_t cntvoff_el2;
  uint8_t __res_68_78[16];
  uint64_t hcr_el2;
  uint64_t hstr_el2;
  uint64_t vpidr_el2;
  uint64_t tpidr_el2;
  uint8_t __res_98_b0[24];
  uint64_t vncr_el2;
  uint8_t __res_b8_100[72];
  uint64_t cpacr_el1;
  uint64_t contextidr_el1;
  uint64_t sctlr_el1;
  uint64_t actlr_el1;
  uint64_t tcr_el1;
  uint64_t afsr0_el1;
  uint64_t afsr1_el1;
  uint64_t esr_el1;
  uint64_t mair_el1;
  uint64_t amair_el1;
  uint8_t __res_158_150[8];
  uint64_t mdscr_el1;
  uint64_t spsr_el1;
  uint64_t cntv_cval_el0;
  uint64_t cntv_ctl_el0;
  uint64_t cntp_cval_el0;
  uint64_t cntp_ctl_el0;
  uint64_t scxtnum_el1;
  uint64_t tfsr_el1;
  uint8_t __res_198_1a8[16];
  uint64_t cntpoff_el2;
  uint8_t __res_1b0_1b8[8];
  uint64_t hfgrtr_el2;
  uint64_t hfgwtr_el2;
  uint64_t hfgitr_el2;
  uint64_t hdfgrtr_el2;
  uint64_t hdfgwtr_el2;
  uint64_t zcr_el1;
  uint8_t __res_1e8_200[24];
  uint64_t ttbr0_el1;
  uint8_t __res_208_210[8];
  uint64_t ttbr1_el1;
  uint8_t __res_218_220[8];
  uint64_t far_el1;
  uint8_t __res_228_230[8];
  uint64_t elr_el1;
  uint8_t __res_238_240[8];
  uint64_t sp_el1;
  uint8_t __res_248_250[8];
  uint64_t vbar_el1;
  uint8_t __res_400_258[424];
  uint64_t ich_lr_el2[16];
  uint64_t ich_ap0r_el2[4];
  uint64_t ich_ap1r_el2[4];
  uint64_t ich_hcr_el2;
  uint64_t ich_vmcr_el2;
  uint8_t __res_4d0_500[48];
  uint64_t vdisr_el2;
  uint64_t vsesr_el2;
  uint8_t __res_510_800[752];
  uint64_t pmblimitr_el1;
  uint8_t __res_808_810[8];
  uint64_t pmbptr_el1;
  uint8_t __res_818_820[8];
  uint64_t pmbsr_el1;
  uint64_t pmscr_el1;
  uint64_t pmsevfr_el1;
  uint64_t pmsicr_el1;
  uint64_t pmsirr_el1;
  uint64_t pmslatfr_el1;
  uint8_t __res_850_880[48];
  uint64_t trfcr_el1;
  uint8_t __res_888_1000[1912];
} arm_vncr_context_t;

typedef struct {
  uint8_t __res_000_008[8];
  uint64_t avncr_el2;
  uint64_t aspsr_el1;
  uint8_t __res_018_100[232];
  uint64_t apctl_el1;
  uint64_t apsts_el1;
  uint64_t vmkey_lo_el2;
  uint64_t vmkey_hi_el2;
  uint64_t apgakeylo_el1;
  uint64_t apgakeyhi_el1;
  uint64_t apiakeylo_el1;
  uint64_t apiakeyhi_el1;
  uint64_t apibkeylo_el1;
  uint64_t apibkeyhi_el1;
  uint64_t apdakeylo_el1;
  uint64_t apdakeyhi_el1;
  uint64_t apdbkeylo_el1;
  uint64_t apdbkeyhi_el1;
  uint64_t kernkeylo_el1;
  uint64_t kernkeyhi_el1;
  uint8_t __res_180_2d0[336];
  uint64_t jctl_el1;
  uint64_t jrange_el1;
  uint64_t japiakeylo_el1;
  uint64_t japiakeyhi_el1;
  uint64_t japibkeylo_el1;
  uint64_t japibkeyhi_el1;
  uint64_t amx_config_el1;
  uint8_t __res_308_360[88];
  uint64_t vmsa_lock_el1;
  uint8_t __res_368_3c0[88];
  uint64_t pmcr1_el1;
  uint8_t __res_3c8_400[56];
  uint64_t apl_lrtmr_el2;
  uint64_t apl_intenable_el2;
  uint8_t __res_410_1000[3056];
} apple_vncr_context_t;

typedef union {
  struct {
    union {
      // arm_context_t guest_context;
      struct {
        uint64_t res1[1];
        struct {
          uint64_t x[29];
          uint64_t fp;
          uint64_t lr;
          uint64_t sp;
          uint64_t pc;
          uint32_t cpsr;
          uint32_t pad;
        } regs;
        uint64_t res2[4];
        struct {
          __uint128_t q[32];
          uint32_t fpsr;
          uint32_t fpcr;
        } neon;
      };
    };
    arm_guest_shared_sysregs_t shared_sysregs;
    arm_guest_banked_sysregs_t banked_sysregs;
    arm_guest_dbgregs_t dbgregs;
    volatile arm_guest_controls_t controls;
    volatile uint64_t state_dirty;
    uint64_t guest_tick_count;
    arm_guest_extregs_t extregs;
    arm_vncr_context_t vncr;
    apple_vncr_context_t avncr;
  };
  uint8_t page[16384];
} arm_guest_rw_context_t;

typedef struct {
  uint32_t vmexit_reason;
  uint32_t vmexit_esr;
  uint32_t vmexit_instr;
  uint64_t vmexit_far;
  uint64_t vmexit_hpfar;
} arm_guest_vmexit_t;

typedef union {
  struct {
    uint64_t ver;
    arm_guest_vmexit_t exit;
    arm_guest_controls_t controls;
    uint64_t state_valid;
    uint64_t state_dirty;
    uint64_t state_used;
    uint32_t ich_vtr_el2;
    uint32_t ich_misr_el2;
    uint32_t ich_elrsr_el2;
  };
  uint8_t page[16384];
} arm_guest_ro_context_t;

typedef struct {
  uint64_t cptr_el2;
  uint64_t mdscr_el1;
  uint64_t tpidr_el1;
  uint64_t tpidr_el0;
  uint64_t tpidrro_el0;
  uint64_t sp_el0;
  uint64_t jop_hash;
  uint64_t vmenter_ticks;
  uint64_t vmexit_ticks;
  uint64_t vncr_el2;
  uint64_t avncr_el2;
  uint64_t ich_ap0r0_el2;
  uint64_t ich_ap1r0_el2;
  vm_map_t guest_map;
  bool flush_local_tlb;
  uint64_t actlr_en_mdsb;
} arm_host_context_t;

typedef struct {
  arm_guest_rw_context_t rw;
  arm_guest_ro_context_t ro;
  arm_host_context_t priv;
} arm_guest_context_t;
