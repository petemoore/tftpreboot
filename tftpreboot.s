.global _start

.set PM_BASE,                    0x3f100000
.set PM_WDOG,                    0x24
.set PM_RSTC,                    0x1c
.set PM_RSTC_WRCFG_CLR,          0xffffffcf
.set PM_RSTC_WRCFG_FULL_RESET,   0x00000020
.set PM_PASSWORD,                0x5a000000

.text

# ------------------------------------------------------------------------------
# Reboots the machine
# See:
#   https://github.com/torvalds/linux/blob/366a4e38b8d0d3e8c7673ab5c1b5e76bbfbc0085/drivers/firmware/raspberrypi.c#L249-L257
#   https://github.com/torvalds/linux/blob/366a4e38b8d0d3e8c7673ab5c1b5e76bbfbc0085/drivers/watchdog/bcm2835_wdt.c#L100-L123
# ------------------------------------------------------------------------------
_start:
  mrs     x0, mpidr_el1          // x0 = Multiprocessor Affinity Register.
  and     x0, x0, #0x3           // x0 = core number.
  cbnz    x0, sleep_core         // Put all cores except core 0 to sleep.
  adr     x10, mbreq             // x10 = memory block pointer for mailbox call.
  mov     w11, 8                 // Mailbox channel 8.
  orr     w2, w10, w11           // Encoded request address + channel number.
  mov     x3, #0xb880            // x3 = lower 16 bits of Mailbox Peripheral Address.
  movk    x3, #0x3f00, lsl #16   // x3 = 0x3f00b880 (Mailbox Peripheral Address)
1:                               // Wait for mailbox FULL flag to be clear.
  ldr     w4, [x3, 0x18]         // w4 = mailbox status.
  tbnz    w4, #31, 1b            // If FULL flag set (bit 31), try again...
  str     w2, [x3, 0x20]         // Write request address / channel number to mailbox write register.
2:                               // Wait for mailbox EMPTY flag to be clear.
  ldr     w4, [x3, 0x18]         // w4 = mailbox status.
  tbnz    w4, #30, 2b            // If EMPTY flag set (bit 30), try again...
  ldr     w4, [x3]               // w4 = message request address + channel number.
  cmp     w2, w4                 // See if the message is for us.
  b.ne    2b                     // If not, try again.

  mov     x0, PM_BASE
  mov     w1, PM_PASSWORD
  mov     w2, #0x0a
  orr     w2, w2, w1
  str     w2, [x0, PM_WDOG]      // [0x3f100024] = 0x5a00000a

  ldr     w3, [x0, PM_RSTC]
  and     w3, w3, PM_RSTC_WRCFG_CLR
  orr     w3, w3, w1
  orr     w3, w3, PM_RSTC_WRCFG_FULL_RESET
  str     w3, [x0, PM_RSTC]      // [0x3f10001c] = ([0x3f10001c] & 0xffffffcf) | 0x5a000020

  # msr     daifset, #2


sleep_core:
  wfe                            // Sleep until woken.
  b sleep_core                   // Go back to sleep.

# Memory block for GPU mailbox call to advise of incoming reboot
.align 4
mbreq:
  .word (mbreq_end-mbreq)        // Buffer size = 24 = 0x18
  .word 0                        // Request/response code
  .word 0x00030048               // Tag 0 - RPI_FIRMWARE_NOTIFY_REBOOT
  .word 0                        //   value buffer size
  .word 0                        //   request: should be 0          response: 0x80000000 (success) / 0x80000001 (failure)
  .word 0                        // End Tags
mbreq_end:
