+++
description = "Base Arch Linux installation with full disk encryption with LUKS and LVM"
date = "2024-03-21T18:40:45Z"
title = "Base Arch Linux installation"
social_image = "https://i.pinimg.com/originals/89/b7/d5/89b7d54e3f6fca2f413f4596a4436262.png"
tags = ["linux-arch"]
categories = [
  "linux"
]
+++

This post is part of a series of posts about installing and configuring Arch Linux in a [Slimbook](https://slimbook.com/en/) Executive 14". I created them from a collection of personal notes, that I thought may be useful for others, so I published them through these series.

1. Base Arch Linux installation
2. [Arch Linux network configuration]({{< ref "arch-linux-network-configuration" >}})
3. [Tracking dotfiles]{{< ref "arch-linux-tracking-dotfiles" >}}

I installed Arch Linux in my new laptop, an [Slimbook](https://slimbook.com/en/) Executive 14".
I followed the [official installation guide](https://wiki.archlinux.org/title/Installation_guide), however, I had to dig through different pages to install it how I wanted.

My requirements were:
- Encrypt the full disk with [dm-crypt](https://en.wikipedia.org/wiki/Dm-crypt).
- Use [LVM](https://sourceware.org/lvm2/) to manage disk partitions.
- Use [ext4](https://en.wikipedia.org/wiki/Ext4) file system.

## Creating disk partitions

I've mostly followed [dm-crypt/Encrypting an entire system](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Overview), but I summarize here my process with the options that I chose.

The laptop has 1 TB of NVMe (Non-Volatile Memory Express) and I deliberately want to encrypt the full disk.

The `dm-crypt` scenario that I've chosen is [LVM on LUKS with encrypted boot partition](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Encrypted_boot_partition_(GRUB)) over:
- The cool [Secure Boot and the Trusted Platform Module option](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LUKS_on_a_partition_with_TPM2_and_Secure_Boot) because, despite, I have to annoyingly type a password every time that I boot the machine, it will be protected from boot [cool boot attacks](https://en.wikipedia.org/wiki/Cold_boot_attack)
- The [LVM on LUKS](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS) because I want to have everything encrypted, included the boot partition (which contains the [initramfs](https://wiki.archlinux.org/title/Arch_boot_process#initramfs) and the kernel).

I used  the ancient [`fdisk`](https://www.man7.org/linux/man-pages/man8/fdisk.8.html) to create in the only disk that the laptop has, which is mapped to the device `/dev/nvme0n1`, all the partitions indicated in [the "preparing the disk" section of LVM on LUKS with encrypted boot partition](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Preparing_the_disk_6). The partitions ended up as:

```
Disk /dev/nvme0n1: 931.51 GiB, 1000204886016 bytes, 1953525168 sectors
Disk model: Samsung SSD 980 PRO 1TB
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: <redacted>

Device           Start        End    Sectors   Size Type
/dev/nvme0n1p1    2048       4095       2048     1M BIOS boot
/dev/nvme0n1p2    4096    2101247    2097152     1G EFI System
/dev/nvme0n1p3 2101248 1953523711 1951422464 930.5G Linux filesystem
```

Let's encrypt the second partition

```
# cyptsetup luksFormat --type luks1 /dev/nvme0n1p3
```

Now let's mount it on `/dev/mapper/cyrptlvm`

```
# cryptsetup open /dev/nvme0n1p3 cryptlvm
```


Now we start with the LVM ceremony

First of all, I create a  physical volume because I only have one hard disk

```
# pvcreate /dev/mapper/cryptlvm
```

Secondly, one logical groups because I don't need an extra degree of isolation between volumes and it's more storage efficient than having multiples groups

```
# vgcreate main /dev/mapper/cryptlvm
```

And last, but not least, three logical volumes, one for swap, one for the root partition, and one for the home directory

```
# lvcreate -L 64G main -n swap
# lvcreate -L 430G main -n root
# lvcreate -l 100%FREE main -n home
```

You may wonder why I'm booking 64 Gb for memory swap. It isn't because I'm scared of running short of RAM, this laptop has exactly 64 Gb. In the past I ran into hibernating issues because the swap partition was smaller than the size of the RAM, although nowadays, [the memory image for the hibernation can be store in a file and not only in a swap partition](https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Hibernation) I preferred to keep it simple and use the swap partition for hibernating because I can afford to lose 64 Gb of disk from the other two partitions and, anyway, if I need to pull up that space, I could do it resizing the LVM volumes.

Time to format the partitions, for the swap partition is a snap. For the other two, I decided to be conservative and use ext4, despite of the cool features that btrfs, I went for ensuring maturity and stability over better data integrity and error recovering and I don't need btrfs RAID, volume management, snapshots, and rollbacks because I already have LVM for them.

So the boring stuff for that is

```
# mkfs.ext4 /dev/main/root
# mkfs.ext4 /dev/main/home
# mkswap /dev/main/swap
# mount /dev/main/root /mnt
# mount --mkdir /dev/main/home /mnt/home
# swapon /dev/main/swap
```

I chose to boot in UEFI mode, so mounted the partition in `/efi` for compatibility with `grup-install`

```
# mkfs.fat -F32 -n EFI /dev/nvme0n1p2
# mount --mkdir /dev/nvme0n1p2 /mnt/efi
```

## Preparation before installing

First of all, we need an internet connection. The Arch Linux installation image comes with [iwd](https://wiki.archlinux.org/title/Iwd), and after I ensured that the Wi-FI network card was detected with `ip link`, I followed the `iwctl` commands  in the [connect to a network](https://wiki.archlinux.org/title/Iwd#Connect_to_a_network) section.

I ensured that the system clock is accurate with `timedateclt`.

## Installing essential packages

```
# pacstrap -K /mnt base linux linux-firmware
```

## Essential configurations

I generate the `fstab` file from the current mounted volumes

```
# genfstab -U /mnt >> /mnt/etc/fstab
```

Then I changed the root directory to the root mounted volume, where we are installing Arch Linux.

```
# arch-chroot /mnt
```

I installed Neovim, which is the editor that I usually use, and I need one to be able to modify and create some configuration files

```
# pacman -S neovim
```

Set the timezone

```
# ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
# hwclock --systohc
```

I uncommented the `ca_ES.UTF-8 UTF-8`, `es_ES.UTF-8 UTF-8`, and `en_US.UTF-8 UTF-8` from `/etc/locale.gen` and generated the locales with

```
# locale-gen
```

I created the file `/etc/locale.conf` and write inside `LANG=en_US.UTF-8` to set the `LANG` variable accordingly.

I configured the hostname writing `blacksmoke` in `/etc/hostname`, yes the laptop is called `blacksmoke`.

I installed the `iwd` network manager

```
# pacman -S iwd
```

I've decided to use a _systemd-based initramfs_, so I  changed the [`mkinitcpio.conf`](https://wiki.archlinux.org/title/Mkinitcpio#Configuration)  (`/etc/mkinitcpio.conf`)  from

```
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
```

to

```
HOOKS=(base systemd autodetect microcode modconf kms keyboard block sd-encrypt lvm2 filesystems fsck)
```

__Note__ I swapped `udev` by `systemd`, added `sd-encrypt` and `lvm2` and removed `keymap` and `consolefont` because I'm fine with the US console keymap and the default console font.

and I installed LVM because it's obviously needed due to my partitions are on top of LVM volumes, besides that `mkinitcpio` needs is as you can see above that I added the `lvm2` hook.

```
# pacman -S lvm2
```

Right after, I regenerated the _initramfs_ running

```
# mkinitcpio -P
```

But I saw through the warnings printed in the console that Im missing a few firmwares. As commented in [Mkinitcpio wiki page about "possible missing firmware for module XXXX](https://wiki.archlinux.org/title/Mkinitcpio#Possibly_missing_firmware_for_module_XXXX), I had to install the Linux firmwares package

```
# pacman -S linux-firmware linux-firmware-qlogic
```

However, it wasn't enough, and I had to install other firmwares from AUR packages, so let's go for them.

As you may know, [installing package from AUR repositories](https://wiki.archlinux.org/title/Arch_User_Repository) is totally different story than doing from main stream repositories, they are several tools that simplify the process by automating several manual steps, however, and I like them, but I want to decide which one to use, once I have the OS working, not at the installation time, so I installed them manually.

First, I installed the required packages to build AUR packages

```
# pacman -S base-devel sudo git
```

I authorized all the users in the `wheel` group creating the following file `/etc/sudoers.d/00-wheel-users`

```
%wheel ALL=(ALL:ALL) ALL
```

And I ensured that only root can access to it

```
  chmod -c 0660 /etc/sudoers.d/00-wheel-users
```

[`makepkg` requires `sudo`](https://wiki.archlinux.org/title/Makepkg#Usage), so it was the time to create my regular user and set it's password

```
# useradd -c "Ivan Fraixedes" -m -U -G wheel ivan
# passwd ivan
```

I adjusted `/etc/makepkg.conf` following the [tips & trics](https://wiki.archlinux.org/title/Makepkg#Tips_and_tricks), creating `/etc/makepkg.conf.d/makepkg.conf` with the following content

```
MAKEFLAGS="-j$(nproc)"

PKGDEST=~/.local/makepkg/packages
SRCDEST=~/.local/makepkg/sources
SRCPKGDEST=~/.local/makepkg/srcpackages
LOGDEST=~/.local/makepkg/logs
```

I logged with my user and created the directories that I configured for `makepkg`

```
# su ivan
# cd ~
# mkdir -p .local/makepkg
# cd .local/makepkg
# mkdir logs packages sources srcpackages
```

I installed the following firmware from AUR doing (as `ivan` user)

```
# mkdir -p tmp/aur
# cd tmp/aur
# git clone https://aur.archlinux.org/upd72020x-fw.git
# cd upd72020x-fw
# makepkg -sirc
```

The same package installation call `mkinitcpio` and I saw that there isn't a warning anymore for the `xhci-pci` firmware, yup!
I repeated the same process for the following AUR firmwares [`ast`](https://aur.archlinux.org/packages/ast-firmware/), [`aic94xxx`](https://aur.archlinux.org/packages/aic94xx-firmware), and [`wd719x`](https://aur.archlinux.org/packages/wd719x-firmware). Cha-ching no more warning when building the _initramfs_ with `mkinitcpio`.

I installed the [GRUB](https://wiki.archlinux.org/title/GRUB) boot loader and the [`efibootmgr`](https://linux.die.net/man/8/efibootmgr) which is required by GRUB for UEFI systems

```
# pacman -S grub efibootmgr
```

And configure it (`/etc/default/grub`) to allow booting from `/boot` on the encrypted partition and set the kernel parameters to allow _initramfs_ to unlock the encrypted root partition using the `sd-encrypt` mkinitcpio's hook.
__Note__ these lines may not be together, some may be commented, and some may have other values that you may need to keep, in any case they will ended up with these values in a different machine (e.g. the disk UUID won't be the same), hence, check the [configuring GRUB](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Configuring_GRUB_2) section.

```
GRUB_ENABLE_CRYPTODISK=y
GRUB_CMDLINE_LINUX="rd.luks.name=a199a1d7-acc0-4910-babb-e0059dec293b=cryptlvm"
```

What disk UUID should you add in the above GRUB's configuration? I think that's quite obvious, but I didn't think that much at that moment and I set to the UUID of the wrong one and, for obvious reasons, GRUB wasn't able to decrypt the volumen and boot the OS :(. It took me several hours to find out  my mistake  and with a lot of rebooting to try to see if I was fixing the issues for every change that I was making in `mkinitcpio.conf`, `grub`, etc., so pay attention and don't waste marvelous hours with this stupid mistake.

It has to be the UUID of the LUKS partition where the `/boot` is placed, NOT the LVM one! In my case is `/dev/nvme0n1p3` and to find out UUID, you can do `ls -l /dev/disk/by-uuid` and the link name that points to it is the UUID.

I installed GRUB to be mounted ESP for UEFI booting and generated the GRUB's configuration file

```
# grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB --recheck
# grub-mkconfig -o /boot/grub/grub.cfg
```

OK, at this point, I rebooted the computer and yes, after booting from its disk, it asked me for the LUKS password, then GRUB menu showed up, and, after selecting boot Arch, it asked me again for LUKS password. Brilliant, everything finally worked.

Last, but not least and before finishing this blog post, I want to include here 2 things as an initial setup.

I did a couple of more things which I consider that they are part of the base installation:
1. Set a password for the `root` user, otherwise you cannot login with it. Yes, I want a password for it, I found sometimes useful in the past to be able to login as `root` rather than my regular user.
2. Add a _keyfile_ to the LUKS partition, so it can be used to decrypted automatically by GRUB and not having to type the LUKS passphrase twice.

After booting up, I login with my regular user `ivan` and then, I access as root and change its password.

```
# sudo su
# passwd
```

Using the root login, I set up the _keyfile_ for the LUKS volume following the ["With a keyfile embedded in the initramfs" section of "dm-crypt/Device encryption" page](https://wiki.archlinux.org/title/Dm-crypt/Device_encryption#With_a_keyfile_embedded_in_the_initramfs).

First, I created the _keyfile_

```
# dd bs=512 count=4 if=/dev/random of=/root/cryptlvm.keyfile iflag=fullblock
# chmod 000 /root/cryptlvm.keyfile
# cryptsetup -v luksAddKey /dev/nvme0n1p3 /root/cryptlvm.keyfile
```

I added the _keyfile_ to the _initramfs_ image, that's just updating the `/etc/mkinicpio.conf`, adding the file path to the `FILES` list, in my case, `FILES` was empty, so it changed from

```
FILES=()
```

to

```
FILES=(/root/cryptlvm.keyfile)
```

Recreate the _initramfs_

```
# mkinitcpio -P
```

Secure the access to the embedded _keyfile_

```
# chmod 600 /boot/initramfs-linux*
```

Update GRUB's configuration (i.e. `/etc/default/grub`) to point to the _keyfile_. Remember, that in my case, I'm using _systemd-based initramfs_ (i.e. `sd-encrypt` hook). I my case, I added `rd.luks.key=a199a1d7-acc0-4910-babb-e0059dec293b=/root/cryptlvm.key` to the `GRUB_CMDLINE_LINUX`, so it changed from

```
GRUB_CMDLINE_LINUX="rd.luks.name=a199a1d7-acc0-4910-babb-e0059dec293b=cryptlvm"
```

to

```
GRUB_CMDLINE_LINUX="rd.luks.name=a199a1d7-acc0-4910-babb-e0059dec293b=cryptlvm rd.luks.key=a199a1d7-acc0-4910-babb-e0059dec293b=/root/cryptlvm.key"
```

And regenerate the GRUB's configuration

```
# grub-mkconfig -o /boot/grub/grub.cfg
```

That's it for today, in future posts, I will cover what tools I'm installing and certain configurations that I tweaked to make my machine more comfortably usable.
