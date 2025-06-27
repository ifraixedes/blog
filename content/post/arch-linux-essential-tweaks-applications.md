+++
description = "Tweak the certain configurations and install some applications to make the computer more usable and make my life easier"
date = "2025-06-27T16:34:45Z"
title = "Arch Linux essential tweaks and applications"
social_image = "https://i.pinimg.com/originals/89/b7/d5/89b7d54e3f6fca2f413f4596a4436262.png"
tags = ["linux-arch"]
categories = [
  "linux"
]
+++

This post is part of a series of posts about installing and configuring Arch Linux in a [Slimbook](https://slimbook.com/en/) Executive 14". I created them from a collection of personal notes, that I thought may be useful for others, so I published them through these series.

1. [Base Arch Linux installation ]({{< ref "arch-linux-base-installation" >}})
2. [Arch Linux network configuration]({{< ref "arch-linux-network-configuration" >}})
3. [Tracking dotfiles]({{< ref "arch-linux-tracking-dotfiles" >}})
4. Arch Linux essential tweaks & applications

This post and the next are related to personalize my recently installed Arch Linux. Although in the previous one, I already made some choices, they are not as personalized as the ones to come.

## Tweaking sudoers

I wanted my user to be able to power off, reboot, etc, using `sudo` but without having to type a password.

To grant my user to do so, I created a new [_sudoers_](https://man.archlinux.org/man/sudoers.5) file `/etc/sudoers.d/10-common-operations-no-passwd` with the following content:

```
ivan blacksmoke= NOPASSWD: /ur/bin/systemctl halt,/ur/bin/systemctl hibernate,/ur/bin/systemctl poweroff,/ur/bin/systemctl reboot,/ur/bin/systemctl suspend
```

And I ensured that only root can access to it

```
# chown root:root /etc/sudoers.d/10-common-operations-no-passwd
# chmod -c 0660 /etc/sudoers.d/10-common-operations-no-passwd
```

## Sync the clock

I wanted to sync the computer clock, so I enable the [systemd-timesyncd](https://wiki.archlinux.org/title/systemd-timesyncd) daemon with

```
# timedatectl set-ntp true
```

## My default shell

I wanted to use the [_fish shell_](https://fishshell.com/), so I installed and set it as a default shell for my user

```
# pacman -S fish
# chsh -s /usr/bin/fish
```

## Changing my default editor

If you have read the [base Arch Linux installation post]({{< ref "arch-linux-base-installation" >}}), I installed NeoVim, but I never set it as my default editor.

As a convention applications that requires to open an editor should read the `EDITOR` environment variable.

The `/etc/environment` file is a file that contains the environment variables thar are exported for all the sessions are created.

I created the file because it didn't exist and I added

```
EDITOR=/usr/bin/nvim
```

## Comfortable using the terminal without a desktop

When you don't have a desktop environment (at least at this point, I didn't have any),  [_tmux_](https://github.com/tmux/tmux) is one of those tools that will be your friend, why? Because between many things, the two most important features for me is that I can have tabs and multiple panes (vertical and horizontal), so I convert a single terminal session in a full fledge environment where I can have several applications running at the same time and move from to another as I do in a desktop environment.

Nowadays, there are similar terminal emulator that may be for some people a better choice, however, this isn't a debate if Tmux is the best, the worse, or the average. I use  [_tmux_](https://github.com/tmux/tmux) because I used for long time, remotely and locally, and it works good for me, so I haven't invested my time on learning another one.

So, yes,  [_tmux_](https://github.com/tmux/tmux) is what I wanted

```
# pacman -S tmux
```

## A few essential tools

The last missing tools at this point were

- `man` because I need to read documentation
- `less` because I need to paginate outputs
- `extfat-utils` because I need to mount external ExtFat disks
- `bat` because syntax coloring to cat certain files is helpful in certain situations
- `vimfm` because is used for certain applications to show file differences

so they were in with

```
# pacman -S man-db extfat-utils less bat vifm
```

## Welcome Arch User Repository

Some good tools aren't in the official Arch linux official package repository, but they are in [AUR (Arch User Repository)](https://aur.archlinux.org/), the package repository manage by the community.

You cannot install [AUR packages](https://wiki.archlinux.org/title/Arch_User_Repository) with `pacman`, buy you can do it manually which isn't that bad, but it's a bit tedious due to the process boilerplate and you have also to repeat it manually to update each installation that you installed from AUR. Fortunately, there are tools that simplify the process and make our busy life easier.

There are many tools to install [AUR packages](https://wiki.archlinux.org/title/Arch_User_Repository). I chose to install [Paru](https://github.com/Morganamilo/paru), however, I don't have a strong argument for it, which is I liked what I read and it's implemented in [Rust](https://rust-lang.org).

Let's install it.

### Paru

First we have to make sure that we have installed and up to date the _basic tools to build Arch Linux Pacakges_ (a.k.a. `base-devel`)
```
# sudo pacman -S --needed base-devel
```

_Paru_ is in the AUR packages, so we have to [install it manually](https://wiki.archlinux.org/title/Arch_User_Repository). After it, we shouldn't recur very often or even never to manually install and update AUR packages, because that's what it will do.

```
# cd .local/makepgk/sources
# git clone https://aur.archlinux.org/paru.git
# cd paru
# makepkg -sirc
```

`makepkg` will ask for installing _Rust_ via the [rust](https://archlinux.org/packages/?name=rust) or [rustup](https://archlinux.org/packages/?name=rustup), I chose _rust_, _rustup_ didn't work because it couldn't select which _Rust_ version to use.

Anyway, the dependency will be deleted after the installation, that's what the `-r` flag does in the `makepkg`.

After the installation, I also deleted `.cargo` and `.rustup` directories that were created in my _home_ directory.

Finally, I wanted to apply [its general tips](https://github.com/Morganamilo/paru?tab=readme-ov-file#general-tips) at the time that I installed.

To apply them and other recommended options:

- I enabled the _pacman's_ `Color`  uncommenting it from `/etc/pacman.conf`.
- In `/etc/paru.conf`, I enabled the file manager viewer to use _vifm_ uncommenting `FileManager` option and making sure that it's set to _vifm_  (i.e. `FileManager = vifm`). Remember to uncomment the `[bin]` section if it's commented because this options belongs to that section.
- In `/etc/paru.conf`, I enabled the search results to start at the bottom and go upwards, uncommenting the option `BottomUp`.  Remember to uncomment the `[options]` section if it's commented because this options belongs to that section.

And that was all for the day.
