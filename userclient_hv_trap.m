@import Darwin;
@import Foundation;

typedef io_object_t io_connect_t;

kern_return_t IOConnectTrap6(io_connect_t connect, uint32_t index, uintptr_t p1, uintptr_t p2,
                             uintptr_t p3, uintptr_t p4, uintptr_t p5, uintptr_t p6);

extern mach_port_t bootstrap_port;
kern_return_t bootstrap_look_up(mach_port_t bp, const char* service_name, mach_port_t* sp);

static mach_port_t gUserClient;
static uint64_t gCodePtrs[14];
static uint64_t gDiscriminant;

static int init_hv_trap() {
  NSError* nserror = nil;
  NSString* inStr = [NSString stringWithContentsOfFile:@"/tmp/zhuowei_portinfo"
                                              encoding:NSUTF8StringEncoding
                                                 error:&nserror];
  if (!inStr) {
    NSLog(@"Error opening portinfo: %@", nserror);
    return 1;
  }
  NSArray<NSString*>* parts = [inStr componentsSeparatedByString:@"\n"];
  int target_pid = parts[0].intValue;

  mach_port_t target_task = 0;
  kern_return_t err;
  err = bootstrap_look_up(bootstrap_port, "com.worthdoingbadly.hypervisor", &target_task);
  if (err) {
    NSLog(@"Can't lookup bootstrap: %d; trying task_for_pid\n", err);
    err = task_for_pid(mach_task_self_, target_pid, &target_task);
    if (err) {
      NSLog(@"Failed to get task port: %s\n", mach_error_string(err));
      return 1;
    }
  }
  if (target_task == MACH_PORT_NULL) {
    NSLog(@"Can't get task port for pid %d\n", target_pid);
    return 1;
  }
  mach_port_name_t remote_port_id = parts[1].intValue;
  mach_port_t user_client = 0;
  mach_msg_type_name_t user_client_type = 0;
  err = mach_port_extract_right(target_task, remote_port_id, MACH_MSG_TYPE_COPY_SEND, &user_client,
                                &user_client_type);
  if (err) {
    NSLog(@"Failed to extract user client port: %s\n", mach_error_string(err));
    return 1;
  }
  NSLog(@"ok port = %u", user_client);
  gDiscriminant = strtoull(parts[2].UTF8String, nil, 0x10);
  for (int i = 0; i < 14; i++) {
    gCodePtrs[i] = strtoull(parts[3 + i].UTF8String, nil, 0x10);
  }
  gUserClient = user_client;
  return 0;
}

kern_return_t hv_trap(unsigned int hv_call, void* hv_arg) {
  static dispatch_once_t init_token;
  dispatch_once(&init_token, ^{
    init_hv_trap();
  });
  if (gUserClient == 0) {
    // TODO(zhuowei): make an error code??
    return 0x1337;
  }
  uint64_t signed_code_ptr = gCodePtrs[hv_call];
  return IOConnectTrap6(gUserClient, /*index=*/0, /*arg1*/ (uintptr_t)hv_arg, /*arg2*/ 0,
                        signed_code_ptr, gDiscriminant, 0, 0);
}
