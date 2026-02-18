# Chapter 13: Upstream Contributions

*In which we learn how to give our fix back to the world, navigate the beautifully chaotic Linux kernel mailing list, and discover that getting code into Linux is part engineering and part social negotiation.*

---

## Why Upstream?

Right now, our fix lives on one laptop. Every time the kernel updates, we have to reinstall patched modules. If HP releases another laptop with the same audio chip, its owner will face the same broken speakers.

**Upstreaming** means getting our patches accepted into the official Linux kernel source code. Once upstream:

- ✅ Every Linux user with this hardware gets the fix automatically
- ✅ Every distribution (Fedora, Ubuntu, Arch, etc.) ships it
- ✅ No more manual module installation
- ✅ Future kernel updates include the fix
- ✅ Other HP Rembrandt laptops with similar hardware benefit too

It's the difference between fixing a pothole on your street and getting the city to repave the road.

## How Linux Kernel Development Works

The Linux kernel is developed by thousands of contributors worldwide. There's no single company in charge (though many companies pay developers to work on it). The process is:

1. **Developer writes a patch** (a diff showing what changed and why)
2. **Developer sends the patch to mailing lists** (yes, email. In 2026. We'll get to that.)
3. **Maintainers review the patch** (ask questions, request changes)
4. **Developer revises and resends** (possibly multiple rounds)
5. **Maintainer accepts and applies** to their subsystem tree
6. **Linus Torvalds merges** subsystem trees during the merge window
7. **New kernel version released** with the fix
8. **Distributions pick it up** in their next kernel update

The whole cycle from patch submission to your distro typically takes **2-6 months**.

> 📧 **Culture shock:** Yes, the Linux kernel — the most important open-source project on Earth, running everything from phones to supercomputers — is developed via email patches. Not GitHub pull requests. Not GitLab merge requests. Plain text email. And it works. Somehow.

## Our Patch Series

We organized our changes into **4 logical patches**, each one doing one thing:

| Patch | Subject | Subsystem |
|-------|---------|-----------|
| 1/4 | ASoC: amd: ps: Add ACP 6.0 (Rembrandt) SoundWire support | sound/soc/amd/ps/ |
| 2/4 | soundwire: amd: Add ACP 6.0 revision support | drivers/soundwire/ |
| 3/4 | ASoC: amd: Add HP Dragonfly Pro SoundWire machine config | sound/soc/amd/acp/ |
| 4/4 | ASoC: amd: Add mipi-sdw-master-list ACPI property fallback | sound/soc/amd/acp/ |

### Why Split Into Multiple Patches?

Kernel culture values **small, focused patches**. Each patch should:
- Do one logical thing
- Be reviewable independently
- Have a clear commit message explaining *why*
- Not break anything if applied alone (as much as possible)

Sending one giant "fix everything" patch is frowned upon. It's hard to review, hard to bisect if something goes wrong, and hard to selectively apply.

## The Commit Message Format

Kernel commit messages follow a specific format:

```
subsystem: component: Short description (under 72 chars)

A paragraph explaining what the patch does and why.

Technical details of the change. Reference specific hardware,
chip revisions, register compatibility, etc.

Mention what was tested and on what hardware.

Signed-off-by: Your Name <your@email.com>
```

The `Signed-off-by` line is legally important — it certifies that you have the right to submit this code and agree to the kernel's Developer Certificate of Origin (DCO).

## Where to Send Patches

Each part of the kernel has designated **maintainers**. You can find them with:

```bash
cd /linux-6.18.9
scripts/get_maintainer.pl patches/0001-*.patch
```

For our patches, the relevant maintainers and lists are:

| Subsystem | Maintainer | Mailing List |
|-----------|-----------|--------------|
| ASoC (sound/soc/) | Mark Brown | alsa-devel@alsa-project.org |
| SoundWire (drivers/soundwire/) | Vinod Koul | alsa-devel@alsa-project.org |
| AMD audio | Vijendar Mukunda (AMD) | alsa-devel@alsa-project.org |

All patches go to `alsa-devel@alsa-project.org` with CC to `linux-kernel@vger.kernel.org` and the specific maintainers.

## Sending Patches by Email

The kernel uses `git send-email` to send patches:

```bash
# Configure git for email
git config sendemail.smtpServer smtp.example.com
git config sendemail.smtpServerPort 587

# Generate patches from commits
git format-patch -5 HEAD

# Send them
git send-email \
    --to alsa-devel@alsa-project.org \
    --cc linux-kernel@vger.kernel.org \
    --cc broonie@kernel.org \
    --cc vkoul@kernel.org \
    0001-*.patch 0002-*.patch 0003-*.patch 0004-*.patch 0005-*.patch
```

### The Cover Letter

For a multi-patch series, it's customary to include a **cover letter** (patch 0/5) that explains the overall problem and solution:

```
Subject: [PATCH 0/5] ASoC/soundwire: amd: Add ACP 6.0 (Rembrandt) SoundWire support

The HP Dragonfly Pro Laptop PC uses AMD Rembrandt (ACP revision 0x60)
with two SoundWire-connected RT1316 speaker amplifiers. Internal 
speakers currently don't work because multiple drivers reject 
revision 0x60.

ACP 6.0 uses an identical register layout to ACP 6.3 (Phoenix) for
SoundWire operations. This series adds 0x60 support to all relevant
drivers and adds the necessary machine configuration.

Tested on HP Dragonfly Pro Laptop PC (board 8A7F) running Fedora 43
with kernel 6.18.9.
```

## What to Expect

After sending patches, expect:

1. **Automated bot responses** — build tests, style checks
2. **Maintainer review** within a few days to a few weeks
3. **Requests for changes** — this is normal! Common asks:
   - "Please split this into smaller patches"
   - "Add a comment explaining why 0x60 is compatible"
   - "Use a #define instead of magic number"
   - "This needs a Fixes: tag"
4. **Multiple revision rounds** (v2, v3, etc.)
5. **Eventual acceptance** into a subsystem tree

> 🎓 **Pro tip:** Don't take review comments personally. Kernel reviewers are direct because they review thousands of patches. "This is wrong, do X instead" is not rude — it's efficient. The culture values correctness over feelings.

## Before Submitting: Checklist

Before sending patches upstream, ensure:

- [ ] Code compiles without warnings (`make W=1`)
- [ ] Code passes style check (`scripts/checkpatch.pl`)
- [ ] Patch applies cleanly against latest `linux-next` tree
- [ ] Commit messages are clear and follow the format
- [ ] Each patch has a `Signed-off-by` line
- [ ] You've tested on actual hardware
- [ ] You've CC'd all relevant maintainers

## The Bigger Picture

Our patches don't just fix one laptop. They potentially fix **every AMD Rembrandt system with SoundWire audio**. That could include other HP models, and potentially laptops from other vendors using the same platform.

By upstreaming, we're:
- Saving future users from the same 15-reboot debugging journey
- Improving AMD audio support in the kernel
- Documenting that ACP 6.0 and 6.3 are register-compatible
- Setting a precedent for how to add new ACP revisions

Open source at its best: fix it once, share it with everyone.

## Key Takeaways

- **Upstreaming** means getting patches into the official Linux kernel
- Kernel development uses **email patches** sent to mailing lists
- Patches should be **small, focused, and well-documented**
- Each subsystem has **maintainers** who review and accept patches
- Expect **review feedback** and multiple revision rounds
- Use `scripts/get_maintainer.pl` to find who to send patches to
- Our fix benefits **all AMD Rembrandt SoundWire systems**, not just one laptop
- The process takes **2-6 months** from submission to distribution release

---

[← Previous: Chapter 12](chapter-12-installing-the-fix.md) | [Next: Chapter 14 — Quizzes →](chapter-14-quiz.md)
