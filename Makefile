KVER ?= $(shell uname -r)
EXTRA ?=
TEST_BUILD ?= 0

.PHONY: source build install uninstall dkms-install dkms-remove test hp-dragonfly-pro clean

# Download and prepare distro-matched kernel source
source:
	@./scripts/fetch-kernel-source.sh $(if $(KVER),--kver $(KVER))

# Build patched modules from kernel source
build:
	@./scripts/build.sh $(if $(KSRC),KSRC=$(KSRC)) KVER=$(KVER) $(if $(EXTRA),EXTRA=$(EXTRA))

# Install built modules, UCM profile, and modprobe config (requires root)
install:
	@./scripts/install.sh $(KVER) $(if $(EXTRA),EXTRA=$(EXTRA))

# Restore original modules from backup (requires root)
uninstall:
	@./scripts/uninstall.sh $(KVER) $(if $(EXTRA),EXTRA=$(EXTRA))

# Register with DKMS for automatic rebuilds on kernel updates (requires root)
dkms-install:
	@./scripts/dkms-install.sh $(KVER) $(if $(EXTRA),EXTRA=$(EXTRA))

# Remove DKMS registration (requires root)
dkms-remove:
	@./scripts/dkms-remove.sh

# Validate patch application (and optional build smoke) via harness
test:
	@./testing/run-harness.sh $(if $(KSRC),--ksrc $(KSRC),--kver $(KVER)) $(if $(KSRC),--no-fetch) $(if $(EXTRA),--extra $(EXTRA)) $(if $(filter 1,$(TEST_BUILD)),--build)

# Remove build artifacts
clean:
	rm -rf compiled/ .build/

# Convenience target for HP Dragonfly Pro machine-specific extras
hp-dragonfly-pro:
	@$(MAKE) build EXTRA=hp-dragonfly-pro $(if $(KSRC),KSRC=$(KSRC)) KVER=$(KVER)
	@$(MAKE) install EXTRA=hp-dragonfly-pro KVER=$(KVER)
