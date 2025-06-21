+++
description = "PGP and Git configurations to start tracking my dotfiles"
date = "2025-06-21T14:29:45Z"
title = "Tracking dotfiles"
social_image = "https://i.pinimg.com/originals/89/b7/d5/89b7d54e3f6fca2f413f4596a4436262.png"
tags = ["linux-arch", "git", "pgp"]
categories = [
  "linux"
]
+++

This post is part of a series of posts about installing and configuring Arch Linux in a [Slimbook](https://slimbook.com/en/) Executive 14". I created them from a collection of personal notes, that I thought may be useful for others, so I published them through these series.

1. [Base Arch Linux installation ]({{< ref "arch-linux-base-installation" >}})
2. [Arch Linux network configuration]({{< ref "arch-linux-network-configuration" >}})
3. Tracking dotfiles

This post isn't specifically related to Arch Linux, however, I dit it before I started to add and modify more configuration files on my home directory (a.k.a _dotfiles_) , I wanted to start tracking them in a Git repository.

Through the years, I've become more disciplined in how to manage my personal computers, one of those things is to track my configurations files (a.k.a _dotfiles_). Nowadays, when I set up a new one, I start to track them in a Git repository.

One purpose is restoring them or take some of them for other installations when they are different ones (not the same OS, or the same one with other applications, etc.), but, the other purposes are:
- To see when new configuration files appear, disappear (i.e. delete) or are modified without being aware.
- Track the changes with useful commit messages, so I can use them to remember how to configure or change certain files to achieve something.

NOTE I don't share this Git repository with anybody. Although it shouldn't contain any secret, I don't want to publicly share it, in case that one slides on it. 

Bear in mind that the commands in this post
- They are all executed from my user home directory.
- They are executed on [Arch Linux](https://archlinux.org/) or a distribution based on it, although the most of them should work in other common Linux distributions.

The starting point is obvious :P
```
# git init -b main .
```

## GPG

Before doing any other thing, I want to set up my GPG keys because I want all my commits to be signed with my _keybase_ signature.

I ensure that that `gnupg` is installed and up to date
```
# sudo pacman -S --needed gnupg
```

I have exported my _keybase_ private key, with the _uid_ that reference to _ifraixedes@keybase.io_ removed, and with _uid_ referencing to my email account under my personal domain, and that's the one that I importing below.

Let's import the key, but before, I list them to see that I don't have any, then import it, and I list them again to see that it was imported as expected, obviously for importing you only need to execute the command in the middle

```
# gpg --list-keys
# gpg --import /mnt/usbstick/personal-gpg.priv.key
# gpg --list-keys
```

## Git

I wanted to have some _Git_ global configuration to start using it with this repository. The content of my initial `.gitconfig` file is

```
[alias]
  amend = commit --amend --no-edit
  brdel = "!f() { git push $1 :$2; }; f"
  graph = log --color --graph --pretty=format:\"%h | %ad | %an | %s%d\" --date=short
  hist = log --color --pretty=format:\"%C(yellow)%h%C(reset) %s%C(bold red)%d%C(reset) %C(green)%ad%C(reset) %C(blue)[%an]%C(reset)\" --relative-date --decorate
  lg = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative
  trdel = "!f() { git push $1 :refs/tags/$2; }; f"
  wdiff = diff --color-words
  wip = for-each-ref --sort='authordate:iso8601' --format=' %(color:green)%(authordate:relative)%09%(color:white)%(refname:short)' refs/heads

[commit]
  gpgSign = true

[core]
  whitepace = blank-at-eol,space-before-tab,blank-at-eol

[init]
  defaultBranch = main

[merge]
  conflictstyle = diff3

[pull]
  ff = only

[push]
  default = current
  followTags = true

[user]
  email = <redacted>
  name = Ivan Fraixedes
  signingkey = B5CB5AD5
```

However the only settings that matters for the signature are
```
[commit]
  gpgSign = true
  
[user]
  email = <redacted>
  name = Ivan Fraixedes
  signingkey = B5CB5AD5
```

I  also create a `.gitignore` file to start ignoring what I don't want to track. I could ignore some entire directories, for example `.local`, however, I don't do it because I want to know when new directories appear there, despite of the extra work that brings in having to update `.gitignore` from time to time.

Last, but not least, I have to define the `GPG_TTY` environment variable, otherwise git commit fails with

```
error: gpg failed to sign the data:
[GNUPG:] KEY_CONSIDERED 2CFC97FB943CDD6F5DD1B8ECFB6101AFB5CB5AD5 2
[GNUPG:] BEGIN_SIGNING H8
[GNUPG:] PINENTRY_LAUNCHED 1117 curses 1.2.1 - linux - - 1000/1000 0
gpg: signing failed: Inappropriate ioctl for device
[GNUPG:] FAILURE sign 83918950
gpg: signing failed: Inappropriate ioctl for device

fatal: failed to write commit object
```

Why? well [`gpg-agent`](https://man.archlinux.org/man/gpg-agent.1) is a daemon which starts automatically to mange secret (a.k.a private) keys. You can read in its documentation it requires `GPG_TTY` environment variable.

Because I use [fishell](https://fishshell.com/), I declare it into a new file under `.config/fish/conf.d/env-vars.fish`

```
set -gx GPG_TTY (tty)
```

and apply it to my session with `source ./config/fish/conf.d/env-vars.fish`.

At this point I created my first commits with the home files that I want to track and I move on from this point creating separated commits for new files, files deletions, and file modifications.