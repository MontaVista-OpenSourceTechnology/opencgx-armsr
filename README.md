# Release repository for generic-arm64

Montavista Software, LLC. release of generic-arm64. 

How to use:
==========
```
git clone -b kirkstone --recursive https://github.com/MontaVista-OpenSourceTechnology/opencgx-armsr
cd opencgx-armsr
source setup.sh
```
Optionally, you can pass setup.sh a directory name to use instead of the
default "project" as follows:

```
source setup.sh <project directory>
```
Note: If you are running setup.sh under another script, you should execute it
as a shell script:

```
bash setup.sh <project directory>
source <project directory>/setup.sh
```
The kernel sources by default will be checked out locally to the sources
directory. If you would rather have bitbake do the checkout run the following
command prior to sourcing setup.sh:

```
export LOCAL_SOURCES=0
```

After running the top level setup.sh, you are ready to build. When starting
another session, you can source the setup.sh script in the project directory
to get started. This script will automatically source the environment for
the build tools stored under buildtools, and sources the 
poky/oe-init-build-env script.

directory layout:
================
```
opencgx-armsr/
       project - bitbake project for the generic-arm64 project build
       buildtools - build tools to provide minimal build requirement for poky builds
       layers - layers for building generic-arm64 project
       setup.sh - project setup script
       bin - various helper applications for setting up and maintaining the release directory
```

Verfied machines: RockPro64, Raspberry Pi 4B

Other SystemReady machines should work, also.

## Installing the Image

This build does not contain firmware, it assume you have ARM
SystemReady already running on your board.  See information below for
firmware image information.

The build output you should use is:

```
  tmp/deploy/images/generic-arm64/core-image-base-generic-arm64.wic
```

which is a full set of bootable partitions that a SystemReady system
will boot automatically.  You can "dd" this straight onto an SD card
or a USB device and it should boot automatically.  You can also use

```
  tmp/deploy/images/generic-arm64/core-image-base-generic-arm64.ext2.gz
```

which you will need to un-gzip and mount on your host system with a
loopback and export via NFS.  Then you can use:

```
  tmp/deploy/images/generic-arm64/Image
```

as a bootable kernel image.  Then you can netboot.

## Firmware for the boards

### RockPro64

Firmware for the RockPro64 can be obtained at
https://github.com/MontaVista-OpenSourceTechnology/rockpro64-firmware
either by building it yourself or using the binaries provided in the
Release area.

Note that the rockpro firmware runs the serial port at 1500000 baud,
you will have to adjust when the board boots the kernel, as the kernel
defaults to 115200 baud.

### QEMU

The instructions at https://github.com/glikely/u-boot-tfa-build show
how to build a qemu version of nor_flash.bin that can be used with
qemu.  However, it doesn't give much in the way of helpful usage
instructions.  You can derive them from the makefile in
scripts/board-qemu-arm.mk.

As an example, you can use:
```
  qemu-system-aarch64 -machine virt,secure=on -cpu cortex-a57 -smp 2 \
    -m 1024 -no-acpi \
    -drive if=virtio,format=raw,file=core-image-minimal-generic-arm64.wic \
    -drive if=pflash,unit=0,format=raw,file=nor_flash.bin
    -net nic,model=virtio -net user,hostfwd=tcp::5556-10.0.2.15:22
```
where you will obviously substitute your image for the wic file.

### NXP i.MX8

NXP says it supports SystemReady on its i.MX8 boards.  There were
issues making this work, though.  The standard binary firmware builds
didn't work, and building from scratch didn't work.

MontaVista worked on the firmware and got it running on the i.MX8MQ
EVK board.  The build for this is at
https://github.com/MontaVista-OpenSourceTechnology/imx-systemready-firmware.git

With that firmware in eMMC, the standard wic image will boot from SD
card or USB stick.

### Raspberry Pi 4B

See
https://github.com/ArmDeveloperEcosystem/systemready-guides/blob/main/Raspberry%20Pi/Raspberry%20Pi%204%20Model%20B/readme.md
for instructions.  The build should boot in SystemReady ES or
SystemReady IR mode, however IR mode seems to have some issues.  The
default is ES, and the web page above describes how to change it, but
you should stick with ES.

Note that you should create a small (16 MB) partition on the SD card
for the image and you should mark it bootable.  The Pi firmware may
not boot it if you use a large partition or if it's not bootable.

The Pi does not have any built-in firmware memory, so you have to boot
it from the SD card.  You may be able to put the build output onto the
SD card, but this has not been tested.  This has only been tested with
a USB flash drive plugge din.

By default the firmware tries PXE boot first, so it may take a long
time to get to the SD card or USB device.  To fix this, hit "ESC" when
prompted to go to Setup, go into "Boot Maintenance Manager", then
"Boot Options", then "Change Boot Order".  Press "Enter" to pull up
the list and use the "+" and "-" keys to move the SD/MMC and USB
device to the top.  Hit "Enter" when done, then choose "Commit Changes
and Exit".  Then you can use "Esc" to get back to the main menu and
continue the boot.

The firmware limits memory to 3GB because of a hardware bug.  The
Linux kernel in this version has a workaround, so you can disable this
limit by going to "Device Manager", "Raspberry Pi Configuration", then
"Advanced Configuration".  Disable "Limit RAM to 3 GB".  When you
escape out, you will be prompted to save.  Then reset the system.
