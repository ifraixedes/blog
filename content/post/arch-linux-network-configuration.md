+++
description = "Configure the network after you base Arch Linux installation"
date = "2024-10-30T17:45:45Z"
title = "Arch Linux network configuration"
social_image = "https://i.pinimg.com/originals/89/b7/d5/89b7d54e3f6fca2f413f4596a4436262.png"
tags = ["linux-arch"]
categories = [
  "linux"
]
+++

This post is part of a series of posts about installing and configuring Arch Linux in a [Slimbook](https://slimbook.com/en/) Executive 14". I created them from a collection of personal notes, that I thought may be useful for others, so I published them through these series.

1. [Base Arch Linux installation ]({{< ref "arch-linux-base-installation" >}})
2. Arch Linux network configuration
3. [Tracking dotfiles]({{< ref "arch-linux-tracking-dotfiles" >}})
4. [Arch Linux essential tweaks & applications]({{< ref "arch-linux-essential-tweaks-applications" >}})

NOTE because all the operations require root permissions, I logged as root with `sudo su`, so all the commands in this post don't execute with `sudo`.

I decided to use [`systemd-networkd`](https://wiki.archlinux.org/title/systemd-networkd) to deal with the network configuration, and I decided to fully commit to it, so I used [`systemd-resolved`](https://wiki.archlinux.org/title/Systemd-resolved) for configuration the _network name resolution_ (a.k.a DNS). Bear in mind that my laptop only has one network interface (apart of the loopback interface).

Both services are part of the base Arch Linux installation.

I enable the `systemd-networkd`, so it automatically starts at boot (i.e. `systemctl enable systemd-networkd.service`). After executing it, you'll see a list of created _symlinks_ in `/etc/systemd/system` and sub-directories to `/usr/lib/systemd/system` directory, not important, but I wanted to point it out.  

I configured the [`systemd-networkd-wait-online.service`](https://wiki.archlinux.org/title/systemd-networkd#systemd-networkd-wait-online) which is a oneshot system service that waits for the network to be configured. I edited the file `/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service` which is a _symlink_ to `/usr/lib/systemd/system/systemd-networkd-network-wait-online.service`, adding the `--any` flag to the following line

```
ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --any
```

To configure the [wireless adapter](https://wiki.archlinux.org/title/systemd-networkd#Wireless_adapter), I created a new file, `/etc/systemd/network/25-wireless.network`, with the following content

```
[Match]
Name=wlan0

[Network]
DHCP=yes
IgnoreCarrierLoss=3
```

To obtain the name of the wireless adapter, I executed `ip link`. 

Everything should be fine at this point, so I started the service `systemd start systemd-netword.service`.

Next is to configure name resolution service (TODO review if name resolution service is correct) through the `systemd-resolved` service.

I started enabling `systemctl enable systemd-resolved.service` which, as before it created some `symlinks` . Right after, I started it `systemctl start systemd-resolved.service`.

[I replaced the `/etc/resolv.conf` by a _symlink_ `ln -sf ../run/systemd/resolve/stub-resolve.conf /etc/resolv.conf`](https://wiki.archlinux.org/title/Systemd-resolved#DNS), the service had to be active, otherwise the runtime configuration (the file `/run/systemd/resolve/stub-resolve.conf`) didn't exist and the _symlink_ creating would have failed.

I checked the DNS currently in use with `resolvectl status` and it was great, it gave me the DNS servers configured on my router.

Last, I configured the Wi-FI through the `iwd`, which I already installed in the [base installation](./arch-linux-base-installation.md)

First, [I created the `iwd` network configuration file](https://wiki.archlinux.org/title/Iwd#WPA-PSK) `/var/lib/iwd/foo.psk`, where `foo` is the SSID of my home Wi-FI network.

I opened the file with the editor and wrote

```
[Security]
Passphrase=I typed here for you to know it
```

Then, I started the service (`systemctl start iwd.service`) and confirmed that I could ping some external sites.

After this, I edited the above file to remove the passphrase because the pre-shared key was written it, so it doesn't need to be there anymore.

Because, [I didn't want `iwd` to scan periodically for networks when it's in a disconnected state](https://wiki.archlinux.org/title/Iwd#Disable_periodic_scan_for_available_networks), I created the `/etc/iwd/main.conf` file, opened with the editor, and wrote:

```
[Scan]
DisablePeriodicScan=true
```

Last but not least, I want the service to automatically start at boot, hence I enabled the service (`systemctl enable iwd.service`), which created some _symlinks_ as before.

This is all, I rebooted my computer and I could verify that it connects automatically to my home Wi-Fi network.