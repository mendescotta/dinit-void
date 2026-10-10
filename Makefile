CC       ?= cc
CFLAGS   ?= -O2 -pipe
CFLAGS   += -Wall
DESTDIR  ?=
LIBEXEC   = /usr/libexec
DINITLIB  = /usr/lib/dinit
DINITSRV  = /usr/lib/dinit.d
DINITETC  = /etc/dinit.d

STAGE1 = pseudofs static-devnodes modules udevd udev-trigger udev-settle console hwclock \
	root-ro storage fsck root-rw filesystems swap misc random-seed sysctl cleanup rcboot \
	pre-network.target network.target network-online loginready boot recovery single
SCRIPTS = pseudofs static-devnodes modules udev console hwclock root-ro storage fsck root-rw \
	filesystems swap misc random-seed sysctl cleanup rcboot network-online shutdown-hook shutdown power
DAEMONS = dhcpcd sshd ssh-keygen dbus elogind polkitd NetworkManager lightdm gdm sddm \
	cosmic-greeter-daemon cosmic-greeter chronyd vmtoolsd vmware-vmblock-fuse vboxservice \
	spice-vdagentd power-profiles-daemon switcheroo-control wpa_supplicant acpid bluetoothd rtkit
TTYS = tty1 tty2 tty3 tty4 tty5 tty6 ttyS0
PROGS = seedrng halt dbus-wait-for

all: $(PROGS)

seedrng: src/seedrng.c
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ $< $(LDFLAGS)
halt: src/halt.c
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ $< $(LDFLAGS)
dbus-wait-for: src/dbus-wait-for.c
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ $< `pkg-config --cflags --libs dbus-1` $(LDFLAGS)

# what both packages ship: early boot, the shutdown hook, the daemon services and their helpers
install: all
	install -d $(DESTDIR)$(DINITLIB) $(DESTDIR)$(DINITSRV) $(DESTDIR)$(DINITETC)/boot.d $(DESTDIR)$(LIBEXEC)
	install -m644 scripts/functions misc/crypt.awk $(DESTDIR)$(DINITLIB)/
	for s in $(SCRIPTS); do install -m755 scripts/$$s $(DESTDIR)$(DINITLIB)/$$s; done
	install -m755 misc/modules-load seedrng halt $(DESTDIR)$(DINITLIB)/
	for s in $(STAGE1); do install -m644 services/$$s $(DESTDIR)$(DINITSRV)/$$s; done
	for s in $(DAEMONS); do install -m644 void/$$s.service $(DESTDIR)$(DINITETC)/$$s; done
	for t in $(TTYS); do sed "s/@TTY@/$$t/g" void/agetty.in > $(DESTDIR)$(DINITETC)/agetty-$$t; done
	install -m755 void/agetty-default void/ssh-keygen $(DESTDIR)$(DINITLIB)/
	install -m755 dbus-wait-for void/dinit-dbus void/dinit-dm $(DESTDIR)$(LIBEXEC)/
	install -Dm644 void/editor.sh $(DESTDIR)/etc/profile.d/editor.sh

# dinit-void: dinit is PID 1 and owns the power commands
install-init:
	install -d $(DESTDIR)/usr/bin
	ln -sf dinit $(DESTDIR)/usr/bin/init
	ln -sf ../lib/dinit/shutdown $(DESTDIR)/usr/bin/shutdown
	for c in halt poweroff reboot soft-reboot; do ln -sf ../lib/dinit/power $(DESTDIR)/usr/bin/$$c; done

# dinit-void-core: boot dinit from a second entry on a root where runit-void owns them
install-alongside:
	install -d $(DESTDIR)$(LIBEXEC) $(DESTDIR)$(DINITLIB)/alongside
	ln -sf ../bin/dinit $(DESTDIR)$(LIBEXEC)/dinit-init
	install -m755 void/dinit-alongside-init $(DESTDIR)$(LIBEXEC)/
	ln -sf ../shutdown $(DESTDIR)$(DINITLIB)/alongside/shutdown
	install -m755 void/alongside-cmd $(DESTDIR)$(DINITLIB)/alongside/halt

check:
	sh -n scripts/functions && for s in $(SCRIPTS); do sh -n scripts/$$s || exit 1; done
	if command -v shellcheck >/dev/null; then shellcheck -s sh -e SC1091,SC2086,SC2046 scripts/*; fi
	# the service graph: every service, its dependencies and options (dinit-check cannot see the
	# commands under the staging root, so only those "could not stat" warnings are ignored)
	if command -v dinit-check >/dev/null; then \
		t=$$(mktemp -d) && $(MAKE) -s install DESTDIR=$$t >/dev/null && \
		out=$$(dinit-check -d $$t$(DINITSRV) -d $$t$(DINITETC) boot recovery single network-online \
			$$(ls $$t$(DINITETC) | grep -v '^boot\.d$$') 2>&1 | grep -v -e 'could not stat' -e '^Checking service' \
			-e '^Performing secondary' -e '^Secondary checks complete' -e '^One or more errors'); \
		rm -rf $$t; if [ -n "$$out" ]; then echo "$$out"; exit 1; fi; echo "dinit-check: service graph ok"; fi

clean:
	rm -f $(PROGS)

.PHONY: all install install-init install-alongside check clean
