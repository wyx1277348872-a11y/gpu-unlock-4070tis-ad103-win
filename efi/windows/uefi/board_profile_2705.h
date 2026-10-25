// SPDX-License-Identifier: GPL-2.0-only
/* Read-only enrolment profile for the RTX 4070 Ti SUPER
 * (AD103, 10de:2705, subsystem 2705:6688, 16 GiB).
 *
 * Used by the probe build only. The unlock build derives its own
 * board_profile.h from a captured probe run, so nothing here is trusted at
 * runtime; this header just lets the read-only probe recognise the card and
 * record it. A chip or VRAM mismatch is logged (chip_matches_profile=) rather
 * than aborting, so a first capture always completes.
 *
 * Confirmed values from two independent cold captures are recorded in
 * PORT-2705.md at the repository root. */
#pragma once
#include <Uefi.h>
#ifndef GU_GENERIC
#define GU_GENERIC 1
#endif
typedef struct {
  UINT32 segment, bus, device, function, subsystem, class_revision, bar0, bar_granularity, vram_mib, rom_bytes;
  char rom_sha256[65], prom_sha256[65];
} GU_PROFILE;
extern GU_PROFILE GuProfile;

/* RTX 4070 Ti SUPER. */
#define GU_BOARD_ID 0x270510deU
#define GU_BOARD_CHIP 0x193000a1U
#define GU_BAR_SIZE 0x1000000U

/* The probe records chip/VRAM instead of refusing the card, so a first capture
 * completes even if a value differs from expectation. The unlock build gate in
 * build.py is unchanged and still refuses anything that is not a cold target. */
#define GU_PROBE_ALLOW_INELIGIBLE 1
#define GU_VRAM_MIN_MIB 16000U
#define GU_VRAM_MAX_MIB 16400U

#define GU_SEGMENT (GuProfile.segment)
#define GU_BUS (GuProfile.bus)
#define GU_DEVICE (GuProfile.device)
#define GU_FUNCTION (GuProfile.function)
#define GU_BOARD_SUBSYSTEM (GuProfile.subsystem)
#define GU_CLASS_REVISION (GuProfile.class_revision)
#define GU_BAR0_CONFIG (GuProfile.bar0)
#define GU_BAR_BASE ((UINT64)GuProfile.bar0)
#define GU_BAR_GRANULARITY (GuProfile.bar_granularity)
#define GU_VRAM_MIB (GuProfile.vram_mib)
#define GU_ROM_BYTES (GuProfile.rom_bytes)
#define GU_ROM_SHA256 (GuProfile.rom_sha256)
#define GU_PROM_SHA256 (GuProfile.prom_sha256)
