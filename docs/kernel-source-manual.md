# Manual kernel source fetching

Use this only if `./scripts/fetch-kernel-source.sh` cannot prepare source automatically.

## Fedora / RHEL-like

```bash
# 1) Get matching source RPM
koji download-build --arch=src kernel-$(uname -r)

# 2) Extract SRPM payload
rpm2cpio kernel-$(uname -r).src.rpm | cpio -idmv

# 3) Extract base tree and apply distro patchset
tar xf linux-$(uname -r | cut -d- -f1).tar.xz
cd linux-$(uname -r | cut -d- -f1)
patch -p1 < ../patch-*-redhat.patch

# 4) Prepare for module builds
cp /boot/config-$(uname -r) .config
cp /usr/src/kernels/$(uname -r)/Module.symvers .
make olddefconfig
make prepare modules_prepare -j"$(nproc)"
```

## Debian / Ubuntu

```bash
# Requires deb-src enabled
apt update
apt source linux
cd linux-*
cp /boot/config-$(uname -r) .config
cp /usr/src/kernels/$(uname -r)/Module.symvers . 2>/dev/null || true
make olddefconfig
make prepare modules_prepare -j"$(nproc)"
```

## Arch-like

```bash
# Option A: pkgctl
pkgctl repo clone linux
cd linux
makepkg --nobuild --nodeps --skipchecksums --skippgpcheck

# Option B: asp
asp checkout linux
cd linux/repos/core-*/  # choose matching repo dir
makepkg --nobuild --nodeps --skipchecksums --skippgpcheck

# Then locate extracted linux source dir and prepare:
cd src/linux-*
cp /boot/config-$(uname -r) .config
cp /usr/lib/modules/$(uname -r)/build/Module.symvers . 2>/dev/null || true
make olddefconfig
make prepare modules_prepare -j"$(nproc)"
```

## Important checks

- Do **not** use `/usr/src/kernels/$(uname -r)` alone as `KSRC` (headers/build tree only).
- `make -s kernelrelease` in the source tree should match `uname -r` (or be adjusted by `EXTRAVERSION`).
- `sound/soc/amd/ps/pci-ps.c` must exist in the source tree.
