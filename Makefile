KVER ?= $(shell uname -r)

.PHONY: build install uninstall dkms-install dkms-remove clean

# Build patched modules from kernel source
build:
	@./scripts/build.sh $(if $(KSRC),KSRC=$(KSRC)) KVER=$(KVER)

# Install built modules, UCM profile, and modprobe config (requires root)
install:
	@./scripts/install.sh $(KVER)

# Restore original modules from backup (requires root)
uninstall:
	@./scripts/uninstall.sh $(KVER)

# Register with DKMS for automatic rebuilds on kernel updates (requires root)
dkms-install:
	@./scripts/dkms-install.sh $(KVER)

# Remove DKMS registration (requires root)
dkms-remove:
	@./scripts/dkms-remove.sh

# Remove build artifacts
clean:
	rm -rf compiled/ .build/
