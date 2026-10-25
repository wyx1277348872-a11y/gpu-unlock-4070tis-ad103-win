// SPDX-License-Identifier: GPL-2.0-only
/* Generic build: everything that differs from card to card is read at run time from
 * \GPU-UNLOCK\PROFILE.TXT, which the program writes itself on its first (read-only) "enrollment" boot.
 * Only the chip family (RTX 4090, AD102) is compiled in. */
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
#define GU_BOARD_ID 0x268410deU
#define GU_BOARD_CHIP 0x192000a1U
#define GU_BAR_SIZE 0x1000000U
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
