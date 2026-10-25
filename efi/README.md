# Boot program (`gpuunlock.efi`) – source and build

This directory is the complete corresponding source of `installer/payload/gpuunlock.efi`.

- `windows/` is a subset of [brandonjank/gpu-unlock-ada](https://github.com/brandonjank/gpu-unlock-ada) at commit `26cea8ede6735155c7333dc637db46166d6ede82`. It holds `build.py`, `THIRD_PARTY_NOTICES.md` and `uefi/`, with this project's changes already applied.
- `patches/generic-mode.patch` is the same changes as a diff against that commit. It touches `windows/build.py`, `uefi/app.c`, `uefi/app_io.c` and `uefi/app_io.h`, and adds `uefi/board_profile_generic.h`. The changes:
  - a `generic` build mode that enrolls the card at its first start (`PROFILE.TXT`) instead of compiling one board's identity into the binary;
  - an automatic mode (`GU_AUTO`) with no countdown, which continues to the next boot entry (Windows) when a check fails;
  - a ring of eight boot logs, `RUN00` to `RUN07`;
  - removal of the exact SS1 selector pin (only the "disabled" condition is required);
  - a refusal to run from a volume that contains `\EFI\Microsoft`.

## Build

Requirements: Linux or WSL, Python 3, and [Zig 0.15.2](https://ziglang.org/download/) (the build uses `zig cc` for the `x86_64-uefi` target).

```sh
cd efi
python3 windows/build.py generic --zig /path/to/zig-0.15.2/zig --output /tmp/gpuunlock-build
sha256sum /tmp/gpuunlock-build/EFI/BOOT/BOOTX64.EFI
```

The output `EFI/BOOT/BOOTX64.EFI` is the file the installer ships as `gpuunlock.efi`. `build-result.json` next to it records the compiler version and the SHA-256 of every source file.

## Reproducing the shipped binary byte for byte

The shipped `gpuunlock.efi` has SHA-256 `5fa4ded58968e3f00b557985603e0ba2a77c6454ceb49d97a4688cdf895dee69` (92 160 bytes). It was built with Zig 0.15.2 from this exact tree.

Diagnostic macros (`GU_DIAG` in `uefi/vendor/diagnostic.h`) embed `__FILE__`, so the absolute source path ends up in the binary. The release was built with the tree at:

```
/root/gpu-unlock-probe/gpu-unlock-ada-generic
```

Put the contents of this `efi/` directory at that path (as root, in WSL or a container), run `python3 windows/build.py generic --zig <zig>`, and the hash matches. This was verified by a rebuild on 2026-10-26.

A build from any other path gives an otherwise identical program whose embedded file-path strings differ, so its hash differs too. A later release may add `-ffile-prefix-map` to make the hash independent of the build path.

If you use your own build, replace `installer/payload/gpuunlock.efi` and update `efi.size` and `efi.sha256` in `installer/payload/manifest.json`. The installer refuses an EFI file that does not match the manifest.

## License

GPL-2.0-only (`LICENSE`). Third-party notices are in `windows/THIRD_PARTY_NOTICES.md` and `windows/uefi/LICENSES/`.
