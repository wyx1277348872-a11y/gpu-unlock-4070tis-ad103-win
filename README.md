# GPU Unlock for Windows — RTX 4070 Ti SUPER (AD103) port

[中文说明](README.zh-CN.md) · **[Port notes for `10de:2705`](PORT-2705.md)**

This is a fork of [Zihao-Wu06/gpu-unlock-for-windows](https://github.com/Zihao-Wu06/gpu-unlock-for-windows)
that adds a reviewed profile for the **RTX 4070 Ti SUPER (`10de:2705`, AD103, 16 GB)** alongside the
original RTX 4090 target. It runs a UEFI program before Windows loads the NVIDIA driver, restores the
full-rate FP32-accumulate tensor path for that one boot, and hands control back to Windows Boot Manager.

> **Experimental. Verified on one PC, one card, four cold boots.** At every start it changes the
> firmware boot order and writes GPU registers. Read [Risks](#risks) first. Use at your own risk.

**This repository distributes source only.** There is no prebuilt EFI and no NVIDIA firmware here;
see [PORT-2705.md](PORT-2705.md) for the measured result on `10de:2705`, the exact changes this fork
makes, and the build steps.

## What you get

Matrix-math throughput on the test card (RTX 4090 24 GB, 450 W limit, PyTorch, single runs):

| Test | Locked (TFLOPS) | Unlocked | Change |
|---|---|---|---|
| TF32 4096³ | 83.7 | ≈130 | **+55 %** (about 2× per clock) |
| FP16, FP32 accumulate, 4096³ | 159.3 | ≈214 | **+35 %** |
| FP16, FP32 accumulate, 8192³ | 152.9 | ≈168 | +10 % |
| BF16, FP32 accumulate, 8192³ | 156.5 | ≈178 | +14 % |
| FP16 with FP16 accumulate, FP32 CUDA cores | — | — | no change |

For the RTX 4070 Ti SUPER port, measured with cuBLAS at a fixed 330 W limit on the same machine:

| Test | Locked (TFLOPS) | Unlocked | Change |
|---|---|---|---|
| FP32, CUDA cores (control) | 29.70 | 29.42 | **0.99×** |
| FP16, FP32 accumulate, 8192³ | 84.92 | 149.67 | **1.76×** |
| FP16, FP16 accumulate (control) | 85.96 | 149.08 | 1.73× |

- Numeric results are bit-identical before and after.
- The card stays at its power limit, so clocks drop and you do not get the theoretical 2×.
- Games, DLSS, ray tracing, INT8 and token-by-token LLM decoding do not benefit. Mining and
  quantised-integer inference do not benefit either. Real applications (training, ComfyUI, LLM
  prefill) have not been measured.

## How it works

1. **Install.** The installer creates a hidden 300 MiB FAT32 partition with no drive letter, or uses a FAT32 USB drive you choose. It copies a small UEFI program there and adds a firmware boot entry, `GPU Unlock (auto)`, ahead of Windows.
2. **Firmware.** The NVIDIA firmware inputs (about 330 MB) are **downloaded and unpacked on your own PC**, with every file checked against a pinned SHA-256. This repository contains no NVIDIA firmware.
3. **Every start.** The UEFI program checks that this is the expected card in a cold state. It then lets the card's signed firmware apply the setting, resets the card, hands the display back and starts Windows. The screen goes black briefly. If any check fails, it writes nothing to the card and Windows starts normally.
4. **First start.** The program reads the card's identity read-only, saves it as `PROFILE.TXT`, and unlocks in the same start.
5. **Volatile.** The setting is lost at power-off and restart, so it is applied again at every start. The switch decides whether the *next* start unlocks, because the unlock has to happen before the NVIDIA driver loads.

## Requirements

The installer's **Check system** button checks each of these and refuses to install if one fails.

| | |
|---|---|
| GPU | Exactly one GeForce RTX 4090, PCI `10de:2684`, 24 GB |
| OS | Windows 10 / 11, 64-bit |
| Boot | UEFI (not Legacy/CSM) |
| Secure Boot | **Off** (the boot program is unsigned) |
| BitLocker / Device Encryption | **Off** (changing the boot path would trigger recovery) |
| Display | Connected to the RTX 4090 only |
| Space | An NTFS volume on a GPT disk that can shrink by 304 MiB, or a FAT32 USB drive with 150 MB free; about 400 MB for downloads |

**Not supported:** 48 GB modded cards, RTX 4090 D, laptop 4090s, multi-GPU, Secure Boot on.

## Tested vs untested

| Verified on the test PC | Not verified |
|---|---|
| Windows 11 Pro 24H2 (26100), driver 610.88 | Windows 10, Home and Server editions |
| ASUS ROG STRIX Z790-H (BIOS 3107), i7-14700KF, ASUS RTX 4090 | Other boards and other 4090 brands; some firmware ignores or resets boot-order changes made from Windows |
| Install, uninstall (the volume is restored to its exact size), switch on/off | USB-drive mode, rollback after a failed install |
| First-start enrollment plus unlock, unlock after cold boot and restart, more than 10 successful unlocks | Behaviour after sleep (S3; the unlock is expected to be lost), with Fast Startup on, after Windows or BIOS updates |
| Download hash checks against a pre-filled cache | A real online download on a fresh PC |
| UI at 100 %, and simulated 125 % and 150 % scaling | User names or paths with non-ASCII characters |

**Reports from other machines are very welcome.** Please open an issue with your board, BIOS version, GPU brand, Windows version and the boot log (button **Boot log**; the `FINAL` line matters most).

## Install

1. Turn **Secure Boot off** in the BIOS, and **BitLocker / Device Encryption off** in Windows. Back up important data.
2. Download the release zip (or clone this repository), open `installer\` and double-click **`GPU-Unlock-Installer.cmd`**. Accept the administrator prompt.
3. Click **Check system**. Every item must say *Pass*; a *Warning* is advisory.
4. Click **Install…**, choose the internal partition (recommended) or a USB drive, tick the risk box, and click **Install**.
5. Restart when asked.

The interface is entirely English or entirely Chinese. Switch with **中文 / English** at the top right.

Command line (administrator PowerShell, inside `installer\`):

```powershell
powershell -ExecutionPolicy Bypass -File core.ps1 check
powershell -ExecutionPolicy Bypass -File core.ps1 install -Mode partition -TargetVolume D -DryRun
powershell -ExecutionPolicy Bypass -File core.ps1 enable | disable | status | logs | reenroll | uninstall
```

`-DryRun` prints the plan without changing anything. `-Lang en|zh` picks the output language.

## Daily use

- **Switch.** The *Auto-unlock at start-up* switch turns the unlock on or off from the next start.
- **Status.** The big card shows whether *this* start is unlocked. Every restart clears the unlock, and the next start applies it again if the switch is on.
- **Skip once.** To skip the unlock for one start, open the firmware boot menu (F8 on ASUS, often F11 or F12 elsewhere) and choose *Windows Boot Manager*.
- **Re-enroll card.** Use this after a GPU swap, a BIOS update or a change to board settings.
- **Uninstall.** This removes the boot entry and the partition, and gives the space back.

To check the speed yourself, run `python tools/bench_gemm.py <label>` (needs PyTorch with CUDA) and compare a locked and an unlocked start. TF32 shows the clearest difference.

The full Chinese manual is in [docs/MANUAL-zh.md](docs/MANUAL-zh.md). It covers troubleshooting, where the files live and manual removal with `bcdedit`.

## Risks

- **Black screen.** The boot program writes GPU registers at every start, with nobody watching. If the transaction fails midway, the program halts and asks you to power off, so the PC can hang on a black screen. Hold the power button, then use the boot menu to start *Windows Boot Manager* and turn the switch off.
- **Disk changes.** Partition mode shrinks one of your volumes. Back up first.
- **Unsigned code.** The scripts and the EFI program are unsigned, so antivirus or SmartScreen may warn. You can build the EFI yourself and compare hashes; see [efi/README.md](efi/README.md).
- **Legal.** This is not legal advice. NVIDIA's driver and firmware terms, anti-circumvention laws (for example 17 U.S.C. §1201) and export-control rules may apply where you live. Decide for yourself whether you may use this.

## Repository layout

| Path | Contents |
|---|---|
| `installer/` | `GPU-Unlock-Installer.cmd`, `gui.ps1` (WinForms GUI), `core.ps1` (all actions), `payload/` (the prebuilt `gpuunlock.efi`, the hash manifest and the local firmware tools) |
| `efi/` | Complete source of `gpuunlock.efi`, its build script, and the patch against upstream |
| `tools/bench_gemm.py` | A/B benchmark |
| `docs/` | Chinese manual and screenshots |

## Credits and license

This builds on public research and code: [Zagitta/gpu-unlock](https://github.com/Zagitta/gpu-unlock), [TOTORONG/AD103_win_unlocker](https://huggingface.co/TOTORONG/AD103_win_unlocker) and [brandonjank/gpu-unlock-ada](https://github.com/brandonjank/gpu-unlock-ada), among others. See [NOTICE.md](NOTICE.md).

Licensed under **GPL-2.0-only** ([LICENSE](LICENSE)). Third-party parts keep their own notices. This project is not affiliated with or endorsed by NVIDIA. NVIDIA, GeForce and RTX are trademarks of NVIDIA Corporation and are used here only to say which hardware this works with.
