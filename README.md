# tftp reboot

This is a bare metal aarch64 kernel for the Raspberry Pi 3B that intends to
reboot the machine when it starts up. When the files are served over TFTP
rather than saved on the SD card, the reboots do not consistently work.

This repository has been created as a test case to demonstrate the issue
described in https://github.com/raspberrypi/firmware/issues/xxxx.
