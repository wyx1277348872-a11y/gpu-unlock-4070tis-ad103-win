/* Modified 2026-10-21: experimental AD103 32GB GA102-pair port; see PORT-NOTES.txt. */
#pragma once
#include "port.h"
EFI_STATUS GuIoOpen(EFI_HANDLE Image,EFI_SYSTEM_TABLE *Table);
EFI_STATUS GuIoClose(VOID);
EFI_STATUS GuLoadAssets(VOID);
EFI_STATUS GuSavePromDump(const VOID *Data,UINTN Size);
EFI_STATUS GuSaveBlob(CHAR16 *Name,const VOID *Data,UINTN Size);
#ifdef GU_GENERIC
EFI_STATUS GuReadParentFile(CHAR16 *Name,char *Out,UINTN Max,UINTN *Length);
EFI_STATUS GuSaveParentBlob(CHAR16 *Name,const VOID *Data,UINTN Size);
#endif
VOID GuReleaseAssets(VOID);
BOOLEAN GuLogReady(VOID);
extern BOOLEAN GuScreenDetached;
VOID GuConsole(const char *Text);
