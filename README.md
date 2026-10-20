# dinit-void

Void Linux booted by [dinit](https://github.com/davmac314/dinit): early boot, shutdown and the
service files for Void's daemons. Packaged in the [voidlab](https://github.com/mendescotta/voidlab)
overlay as `dinit-void` (dinit is PID 1) and `dinit-void-core` (boots dinit from a second boot entry
on a runit host, for testing).

It does what runit's stage 1 and 3 do on Void, with the same configuration: `/etc/rc.conf`
(`KEYMAP`, `FONT`, `TTYS`, `HARDWARECLOCK`, `TIMEZONE`, `CGROUP_MODE`), `/etc/hostname`, `/etc/fstab`,
`/etc/crypttab`, `modules-load.d`, `sysctl.d`, `/etc/rc.local` and `/etc/rc.shutdown`.

## Boot

Each step is a dinit service (`/usr/lib/dinit.d`) running a short script (`/usr/lib/dinit`):

```
pseudofs ─ static-devnodes ─ modules ─ udevd ─ udev-trigger ─ udev-settle ─ console, hwclock
root-ro ─ storage (RAID, btrfs, LVM, crypttab, ZFS) ─ fsck ─ root-rw ─ filesystems
filesystems ─ swap, misc (utmp, machine-id, hostname, loopback, timezone), random-seed, sysctl, cleanup
rcboot (all of the above, then /etc/rc.local)
├─ pre-network.target ─ network.target ─ network-online
└─ loginready (gettys, display managers)
boot = rcboot + loginready + network.target + everything linked in /etc/dinit.d/boot.d
```

A failing step makes dinit offer `recovery` (`sulogin`). Enable a service with
`ln -s ../<name> /etc/dinit.d/boot.d/`. Daemon services in `/etc/dinit.d` depend on `rcboot`; network
daemons on `pre-network.target`, before `network.target`; display managers on `loginready`.
Void's `turnstile` package owns `/etc/dinit.d/turnstiled`, written for Chimera's `local.target` and
`login.target`; images that use it replace it with one that depends on `elogind` and starts before
`loginready`, so it accepts PAM sessions before GDM or a getty logs anyone in. User services linked
in `/usr/lib/dinit.d/user/boot.d` start with each user's dinit.

At shutdown dinit stops the services and kills what is left, then `/usr/lib/dinit/shutdown-hook`
runs `/etc/rc.shutdown`, saves the random seed and the clock, writes wtmp, unmounts and closes LVM
and dm-crypt, in Void's order.

`make` builds the helpers, `make check` validates the service graph (`dinit-check`) and the scripts,
`make install` installs everything both packages share, `make install-init` makes dinit PID 1 and
owner of `shutdown`/`halt`/`poweroff`/`reboot`, `make install-alongside` adds the second-entry glue.

## Where it comes from

- The steps and their order: void-runit's `core-services` and `shutdown.d` (public domain); each
  script names its source. `seedrng.c`, `halt.c`, `crypt.awk` and `modules-load` are void-runit's.
- The service style (`boot` with `waits-for.d`, `rcboot`, `loginready`, `recovery`, `single`, the
  console and interruptible fsck options): dinit's example boot, as KaOS ships it (Apache-2.0).
- `network-online`: noid-dinit's port of OpenRC's net-online (BSD-2-Clause, `LICENSES/BSD-2-Clause-OpenRC`).
- `dbus-wait-for` and the cgroup v2 controller setup: q66 (BSD-2-Clause), from Chimera Linux.
- The daemon services and their helpers in `void/`: ours, BSD-2-Clause (`LICENSES/BSD-2-Clause-Artix`
  has the text they were first published under).

Nothing is fetched from another project at build or run time.
