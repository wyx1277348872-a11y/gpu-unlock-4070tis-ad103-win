<#
GPU Unlock - front end (WinForms, Windows PowerShell 5.1, no extra software needed).
All real work is done by core.ps1; this window only starts it and shows what it prints.
The interface is entirely English or entirely Chinese; the switch at the top right changes it and the choice is saved per user.
-Snapshot/-SnapshotCheck/-SnapshotDialog render the window to PNG files and exit (used to check the layout without a screen).
#>
param([string]$Lang = '', [string]$Snapshot = '', [switch]$SnapshotCheck, [string]$SnapshotDialog = '', [double]$ForceScale = 0)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Core = Join-Path $Root 'core.ps1'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $Snapshot) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"' + $PSCommandPath + '"'))
    exit
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# crisp text on scaled (125%/150%) screens instead of a blurry stretched bitmap
try { Add-Type -Namespace Win32 -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'; [void][Win32.Dpi]::SetProcessDPIAware() } catch { }
[System.Windows.Forms.Application]::EnableVisualStyles()
# Layout is written for 96 DPI and scaled by hand to the screen's DPI (fonts in points already follow the DPI).
# WinForms auto-scaling did not move the controls when they are added in code, so text overflowed on 150% screens.
# -ForceScale imitates a scaled screen for layout snapshots taken at 96 DPI (it also enlarges the fonts).
$script:sf = 1.0; $script:fontMul = 1.0
if ($ForceScale -gt 0) { $script:sf = $ForceScale; $script:fontMul = $ForceScale }
else { try { $gfx = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $script:sf = $gfx.DpiX / 96.0; $gfx.Dispose() } catch { } }
$Manifest = Get-Content -LiteralPath (Join-Path $Root 'payload\manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json

# ------------------------------------------------------------------------------------------ language
$PrefPath = 'HKCU:\Software\GPU-Unlock'
$script:lang = $Lang
if ($script:lang -notin 'en', 'zh') { try { $script:lang = (Get-ItemProperty -Path $PrefPath -ErrorAction Stop).Lang } catch { } }
if ($script:lang -notin 'en', 'zh') { $script:lang = $(if ((Get-UICulture).Name -like 'zh*' -or (Get-Culture).Name -like 'zh*') { 'zh' } else { 'en' }) }

$Text = @{
    en = @{
        appName = 'GPU Unlock'; title = 'RTX 4090 Compute Unlock'; subtitle = 'Windows pre-boot unlock  ·  v{0}'
        heroLoading = 'Reading status…'; statusFail = 'Could not read the status'
        heroUnlocked = 'Unlocked for this session'; heroFailed = 'The unlock failed this time'; heroLocked = 'Not unlocked right now'
        heroPending = 'Installed — restart to unlock'; heroNotInstalled = 'Not installed'
        notInstalledSub = 'Click “Check system” to see whether this PC is suitable, then “Install…”.'
        swOn = 'Auto-unlock is on: every start unlocks the card before Windows loads.'
        swOff = 'Auto-unlock is off: the PC starts normally, without unlocking.'
        swNotFirst = 'The boot entry exists but is not first in the boot order; switch it on again.'
        runThis = 'Unlocked at {0}.'; runFailed = 'The boot program ran at {0} but stopped at stage “{1}”. See the boot log.'
        runEarlier = 'Last run {0} was in an earlier start; every restart clears the unlock.'
        noRun = 'No boot log yet.'; restartHint = ' Restart to unlock.'
        tglLabel = 'Auto-unlock at start-up'; tglOn = 'On'; tglOff = 'Off'; tglNotFirst = 'Not first'; tglNA = 'Not installed'; applies = 'changes apply at the next start'
        tInstall = 'Installation'; vInstalled = 'Installed · {0}'; modePart = 'partition'; modeUsb = 'USB drive'; vNotInstalled = 'Not installed'
        tFiles = 'Boot files'; vComplete = 'Complete'; vIncomplete = 'Missing'
        tProfile = 'Card profile'; vEnrolled = 'Enrolled'; vNotEnrolled = 'At next start'; tVersion = 'Version'
        bCheck = 'Check system'; bInstall = 'Install…'; bReenroll = 'Re-enroll card'; bLogs = 'Boot log'; bUninstall = 'Uninstall'
        tabLog = 'Activity'; tabCheck = 'System check'; busy = 'Working'
        cStatus = 'Status'; cName = 'Check'; cDetail = 'Details'; sOk = 'Pass'; sWarn = 'Warning'; sFail = 'Fail'
        checkSummary = 'Check finished: {0} passed, {1} warnings, {2} failed.'
        footer = 'Experimental software: it changes the firmware boot order and writes GPU registers at every start. Verified on one 24 GB RTX 4090 only. Use at your own risk.'
        ready = 'Ready. Click “Check system” to see whether this PC is suitable.'; langChanged = 'Language: English'
        bootLogNote = 'Raw log of the boot program (technical output, English only):'
        readingDisks = 'Reading the disk list; the install window opens in a few seconds…'
        msgOn = "Auto-unlock is on. It takes effect at the next start; this session is unchanged.`r`n`r`nRestart now?"
        msgOff = "Auto-unlock is off. From the next start the card is no longer unlocked; this session stays as it is until you restart.`r`n`r`nRestart now?"
        reenrollQ = "Delete the saved card profile? The next start reads the card again and saves a new one.`r`n`r`nUse this after changing the GPU, updating the BIOS or changing board settings."
        uninstallQ = "Remove the boot entry and the program files?`r`n`r`nIn partition mode the small partition is deleted and its space goes back to the volume it came from."
        installedQ = "Installed. Restart now?`r`n`r`nThe first start reads the card, then unlocks it in the same start."
        installFailed = 'The install did not finish; a rollback was attempted. See Activity for details.'
        dlgTitle = 'Install'; dlgHead = 'Where should the program and firmware files live?'
        optPart = 'A small partition on an internal disk (recommended)'
        optPartNote = 'Shrinks the chosen volume by 304 MiB and creates a 300 MiB FAT32 partition with no drive letter. Whether it can shrink is checked before anything changes.'
        optUsb = 'A FAT32 USB drive (no partition changes)'
        optUsbNote = 'Nothing is formatted. Keep it plugged in; without it the PC simply starts Windows.'
        steps = "Install will:`r`n1.  Download about 330 MB of NVIDIA firmware inputs and verify their hashes (unpacked on this PC only, never shipped with this tool).`r`n2.  Prepare the location chosen above.`r`n3.  Add a firmware boot entry.`r`nAt the first restart the card is read, then unlocked in the same start."
        chkEnable = 'Turn auto-unlock on after installing'; chkRisk = 'I understand this is experimental and use it at my own risk'
        bGo = 'Install'; bCancel = 'Cancel'
        partItem = '{0}:   ·   {1} GB free'; sysSuffix = '   ·   system drive'; recSuffix = '   ·   recommended'; usbItem = '{0}:   {1}   ·   {2} MB free'; noneFound = 'None found'
    }
    zh = @{
        appName = 'GPU 解锁'; title = 'RTX 4090 算力解锁'; subtitle = 'Windows 开机前解锁  ·  v{0}'
        heroLoading = '正在读取状态…'; statusFail = '无法读取状态'
        heroUnlocked = '本次开机已解锁'; heroFailed = '本次开机解锁失败'; heroLocked = '当前未解锁'
        heroPending = '已安装，重启后解锁'; heroNotInstalled = '尚未安装'
        notInstalledSub = '先点“检查系统”确认这台电脑是否适用，再点“安装…”。'
        swOn = '自动解锁已开启：每次开机都会在 Windows 加载前解锁显卡。'
        swOff = '自动解锁已关闭：电脑正常启动，不再解锁。'
        swNotFirst = '启动项存在，但不在启动顺序第一位；请重新打开开关。'
        runThis = '解锁于 {0}。'; runFailed = '开机程序于 {0} 运行，但停在“{1}”阶段。详见开机日志。'
        runEarlier = '最近一次运行（{0}）属于更早的开机；每次重启都会清除解锁。'
        noRun = '还没有开机日志。'; restartHint = '重启即可解锁。'
        tglLabel = '开机自动解锁'; tglOn = '已开启'; tglOff = '已关闭'; tglNotFirst = '不在第一位'; tglNA = '未安装'; applies = '改动下次开机生效'
        tInstall = '安装状态'; vInstalled = '已安装 · {0}'; modePart = '硬盘分区'; modeUsb = 'U 盘'; vNotInstalled = '未安装'
        tFiles = '开机程序文件'; vComplete = '完整'; vIncomplete = '缺失'
        tProfile = '显卡信息'; vEnrolled = '已登记'; vNotEnrolled = '下次开机登记'; tVersion = '版本'
        bCheck = '检查系统'; bInstall = '安装…'; bReenroll = '重新登记显卡'; bLogs = '开机日志'; bUninstall = '卸载'
        tabLog = '运行记录'; tabCheck = '系统检查'; busy = '正在处理'
        cStatus = '状态'; cName = '检查项'; cDetail = '详情'; sOk = '通过'; sWarn = '注意'; sFail = '未通过'
        checkSummary = '检查完成：{0} 项通过，{1} 项注意，{2} 项未通过。'
        footer = '实验性软件：会修改固件启动顺序，并在每次开机时写显卡寄存器。仅在一块 24 GB RTX 4090 上验证过，风险自负。'
        ready = '准备就绪。点击“检查系统”，看看这台电脑是否适用。'; langChanged = '语言：中文'
        bootLogNote = '开机程序的原始日志（技术输出，只有英文）：'
        readingDisks = '正在读取磁盘列表，几秒后打开安装窗口…'
        msgOn = "已开启自动解锁。下次开机生效，当前这次开机不变。`r`n`r`n现在重启吗？"
        msgOff = "已关闭自动解锁。下次开机起不再解锁；当前这次开机保持现状，直到重启。`r`n`r`n现在重启吗？"
        reenrollQ = "删除已保存的显卡信息？下次开机会重新读取并保存。`r`n`r`n适用于更换显卡、升级 BIOS 或改动主板设置之后。"
        uninstallQ = "删除启动项和程序文件？`r`n`r`n硬盘分区模式下会删除那个小分区，并把空间还给原来的卷。"
        installedQ = "安装完成。现在重启吗？`r`n`r`n第一次开机会先读取显卡信息，然后在同一次开机里解锁。"
        installFailed = '安装没有完成，已尝试回滚。详情见“运行记录”。'
        dlgTitle = '安装'; dlgHead = '程序和固件文件放在哪里？'
        optPart = '内部硬盘上的小分区（推荐）'
        optPartNote = '把所选卷缩小 304 MiB，新建一个 300 MiB、没有盘符的 FAT32 分区。改动前会先检查能否缩小，不行就停止。'
        optUsb = 'FAT32 格式的 U 盘（不改分区）'
        optUsbNote = '不会格式化。需要一直插着；拔掉后电脑直接正常启动 Windows。'
        steps = "安装会：`r`n1.  下载约 330 MB 的 NVIDIA 固件包并核对哈希（只在本机提取，不随本工具分发）。`r`n2.  准备上面选择的位置。`r`n3.  添加一个固件启动项。`r`n重启后第一次开机会先读取显卡信息，然后在同一次开机里解锁。"
        chkEnable = '安装后立即开启自动解锁'; chkRisk = '我了解这是实验性软件，风险自负'
        bGo = '开始安装'; bCancel = '取消'
        partItem = '{0}:   ·   可用 {1} GB'; sysSuffix = '   ·   系统盘'; recSuffix = '   ·   推荐'; usbItem = '{0}:   {1}   ·   可用 {2} MB'; noneFound = '未找到'
    }
}
function T([string]$Key) { return $Text[$script:lang][$Key] }

# ------------------------------------------------------------------------------------------ look
function C([string]$Hex) { return [System.Drawing.ColorTranslator]::FromHtml($Hex) }
$Pal = @{
    Bg = (C '#F3F4F6'); Card = (C '#FFFFFF'); Line = (C '#E5E7EB'); Ink = (C '#111827'); Muted = (C '#6B7280')
    Head = (C '#111827'); HeadMuted = (C '#9CA3AF'); HeadLine = (C '#374151'); Accent = (C '#22C55E')
    Ok = (C '#16A34A'); OkInk = (C '#15803D'); Bad = (C '#DC2626'); BadInk = (C '#B91C1C'); Warn = (C '#D97706'); Idle = (C '#9CA3AF')
    Console = (C '#0D1117'); ConsoleInk = (C '#C9D1D9'); Primary = (C '#111827'); PrimaryHover = (C '#1F2937'); Disabled = (C '#D1D5DB')
    BtnLine = (C '#D1D5DB'); Hover = (C '#F9FAFB'); DangerLine = (C '#FCA5A5'); DangerHover = (C '#FEF2F2'); Soft = (C '#F9FAFB'); FootInk = (C '#92400E')
}
$script:fonts = New-Object System.Collections.ArrayList
function UiFamily { if ($script:lang -eq 'zh') { return 'Microsoft YaHei UI' }; return 'Segoe UI' }
function F([single]$Size, [string]$Style = 'Regular') { return New-Object System.Drawing.Font((UiFamily), ([single]($Size * $script:fontMul)), ([System.Drawing.FontStyle]$Style)) }
function Set-Font($Ctl, [single]$Size, [string]$Style = 'Regular') { [void]$script:fonts.Add(@($Ctl, $Size, $Style)); $Ctl.Font = F $Size $Style }
function Apply-Fonts { foreach ($x in $script:fonts) { $x[0].Font = F $x[1] $x[2] } }

function New-Lbl($Parent, $X, $Y, $W, $H, [single]$Size = 9, [string]$Style = 'Regular', $Color = $null, [switch]$NoTrack) {
    $l = New-Object System.Windows.Forms.Label
    $l.Location = New-Object System.Drawing.Point($X, $Y); $l.Size = New-Object System.Drawing.Size($W, $H)
    $l.BackColor = [System.Drawing.Color]::Transparent
    $l.ForeColor = $(if ($Color) { $Color } else { $Pal.Ink })
    if ($NoTrack) { $l.Font = F $Size $Style } else { Set-Font $l $Size $Style }
    $Parent.Controls.Add($l); return $l
}
function New-Btn($Parent, $X, $Y, $W, $H, [string]$Kind = 'secondary', [switch]$NoTrack) {
    $b = New-Object System.Windows.Forms.Button
    $b.Location = New-Object System.Drawing.Point($X, $Y); $b.Size = New-Object System.Drawing.Size($W, $H)
    $b.FlatStyle = 'Flat'; $b.UseVisualStyleBackColor = $false; $b.Cursor = [System.Windows.Forms.Cursors]::Hand; $b.Tag = $Kind
    switch ($Kind) {
        'primary' { $b.BackColor = $Pal.Primary; $b.ForeColor = [System.Drawing.Color]::White; $b.FlatAppearance.BorderSize = 0; $b.FlatAppearance.MouseOverBackColor = $Pal.PrimaryHover; $b.FlatAppearance.MouseDownBackColor = $Pal.Ink }
        'danger' { $b.BackColor = $Pal.Card; $b.ForeColor = $Pal.BadInk; $b.FlatAppearance.BorderColor = $Pal.DangerLine; $b.FlatAppearance.MouseOverBackColor = $Pal.DangerHover }
        default { $b.BackColor = $Pal.Card; $b.ForeColor = $Pal.Ink; $b.FlatAppearance.BorderColor = $Pal.BtnLine; $b.FlatAppearance.MouseOverBackColor = $Pal.Hover }
    }
    if ($NoTrack) { $b.Font = F 9.5 } else { Set-Font $b 9.5 }
    $Parent.Controls.Add($b); return $b
}
function Set-BtnEnabled($B, [bool]$On) {
    $B.Enabled = $On
    if ($B.Tag -eq 'primary') { $B.BackColor = $(if ($On) { $Pal.Primary } else { $Pal.Disabled }) }
}
function New-Card($Parent, $X, $Y, $W, $H, $Fill = $null) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point($X, $Y); $p.Size = New-Object System.Drawing.Size($W, $H)
    $p.BackColor = $(if ($Fill) { $Fill } else { $Pal.Card })
    $p.Add_Paint({ param($s, $e) $pen = New-Object System.Drawing.Pen($Pal.Line); $e.Graphics.DrawRectangle($pen, 0, 0, $s.ClientSize.Width - 1, $s.ClientSize.Height - 1); $pen.Dispose() })
    $Parent.Controls.Add($p); return $p
}

# ------------------------------------------------------------------------------------------ window
$form = New-Object System.Windows.Forms.Form
$form.AutoScaleMode = 'None'
$form.ClientSize = New-Object System.Drawing.Size(900, 650)
$form.FormBorderStyle = 'FixedSingle'; $form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'; $form.BackColor = $Pal.Bg
Set-Font $form 9

# header band
$head = New-Object System.Windows.Forms.Panel
$head.Location = New-Object System.Drawing.Point(0, 0); $head.Size = New-Object System.Drawing.Size(900, 64); $head.BackColor = $Pal.Head
$form.Controls.Add($head)
$lblTitle = New-Lbl $head 22 9 600 30 15 'Bold' ([System.Drawing.Color]::White)
$lblSub = New-Lbl $head 24 40 600 18 8.5 'Regular' $Pal.HeadMuted
$seg = New-Object System.Windows.Forms.Panel
$seg.Location = New-Object System.Drawing.Point(762, 18); $seg.Size = New-Object System.Drawing.Size(114, 28); $seg.BackColor = $Pal.HeadLine
$head.Controls.Add($seg)
$segZh = New-Lbl $seg 2 2 55 24 9 'Regular' -NoTrack; $segZh.Text = '中文'
$segEn = New-Lbl $seg 57 2 55 24 9 'Regular' -NoTrack; $segEn.Text = 'English'
foreach ($l in $segZh, $segEn) { $l.TextAlign = 'MiddleCenter'; $l.Cursor = [System.Windows.Forms.Cursors]::Hand }
$segZh.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', ([single](9 * $script:fontMul))); $segEn.Font = New-Object System.Drawing.Font('Segoe UI', ([single](9 * $script:fontMul)))
$strip = New-Object System.Windows.Forms.Panel
$strip.Location = New-Object System.Drawing.Point(0, 64); $strip.Size = New-Object System.Drawing.Size(900, 3); $strip.BackColor = $Pal.Accent
$form.Controls.Add($strip)

# hero card: what state the card is in right now, and the switch
$hero = New-Card $form 24 84 852 114
$dot = New-Object System.Windows.Forms.Panel
$dot.Location = New-Object System.Drawing.Point(24, 24); $dot.Size = New-Object System.Drawing.Size(14, 14); $dot.BackColor = $Pal.Card
$hero.Controls.Add($dot)
$script:dotColor = $Pal.Idle
$dot.Add_Paint({ param($s, $e) $e.Graphics.SmoothingMode = 'AntiAlias'; $br = New-Object System.Drawing.SolidBrush($script:dotColor); $e.Graphics.FillEllipse($br, 0, 0, $s.ClientSize.Width - 1, $s.ClientSize.Height - 1); $br.Dispose() })
$lblHero = New-Lbl $hero 46 12 540 34 15 'Bold'
$lblHeroSub = New-Lbl $hero 48 50 520 58 9 'Regular' $Pal.Muted
$lblTgl = New-Lbl $hero 560 20 200 30 10 'Bold'; $lblTgl.TextAlign = 'MiddleRight'
$tgl = New-Object System.Windows.Forms.Panel
$tgl.Location = New-Object System.Drawing.Point(772, 21); $tgl.Size = New-Object System.Drawing.Size(56, 28); $tgl.BackColor = $Pal.Card
$hero.Controls.Add($tgl)
$lblTglNote = New-Lbl $hero 520 58 308 20 8.5 'Regular' $Pal.Muted; $lblTglNote.TextAlign = 'MiddleRight'
$script:tglOn = $false; $script:tglEnabled = $false
$tgl.Add_Paint({
    param($s, $e)
    $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
    $w = [single]($s.ClientSize.Width - 1); $h = [single]($s.ClientSize.Height - 1)
    $col = $(if (-not $script:tglEnabled) { $Pal.Line } elseif ($script:tglOn) { $Pal.Ok } else { $Pal.Disabled })
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc([single]0, [single]0, $h, $h, [single]90, [single]180)
    $path.AddArc([single]($w - $h), [single]0, $h, $h, [single]270, [single]180)
    $path.CloseFigure()
    $br = New-Object System.Drawing.SolidBrush($col); $g.FillPath($br, $path); $br.Dispose(); $path.Dispose()
    $k = [single]($h - 6); $kx = $(if ($script:tglOn) { [single]($w - $h + 3) } else { [single]3 })
    $kb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White); $g.FillEllipse($kb, $kx, [single]3, $k, $k); $kb.Dispose()
})

# four facts
$tileT = @(); $tileV = @()
for ($i = 0; $i -lt 4; $i++) {
    $tc = New-Card $form (24 + $i * 216) 210 204 64
    $tileT += New-Lbl $tc 14 9 180 18 8.5 'Regular' $Pal.Muted
    $tileV += New-Lbl $tc 14 29 184 28 11 'Bold'
}

# actions
$btnCheck = New-Btn $form 24 288 132 36
$btnInstall = New-Btn $form 166 288 132 36 'primary'
$btnReenroll = New-Btn $form 308 288 150 36
$btnLogs = New-Btn $form 468 288 132 36
$btnUninstall = New-Btn $form 744 288 132 36 'danger'

# tabs: activity log / system check
$tabLog = New-Lbl $form 24 338 100 22 10 'Bold'; $tabLog.AutoSize = $true
$tabCheck = New-Lbl $form 140 338 100 22 10 'Bold'; $tabCheck.AutoSize = $true
foreach ($l in $tabLog, $tabCheck) { $l.Cursor = [System.Windows.Forms.Cursors]::Hand }
$tabLine = New-Object System.Windows.Forms.Panel
$tabLine.Size = New-Object System.Drawing.Size(60, 2); $tabLine.BackColor = $Pal.Ink; $tabLine.Location = New-Object System.Drawing.Point(24, 362)
$form.Controls.Add($tabLine)
$lblBusy = New-Lbl $form 576 338 300 22 9 'Regular' $Pal.Warn; $lblBusy.TextAlign = 'MiddleRight'; $lblBusy.Visible = $false

$content = New-Object System.Windows.Forms.Panel
$content.Location = New-Object System.Drawing.Point(24, 368); $content.Size = New-Object System.Drawing.Size(852, 236); $content.Padding = New-Object System.Windows.Forms.Padding(1); $content.BackColor = $Pal.Console
$form.Controls.Add($content)
$logWrap = New-Object System.Windows.Forms.Panel
$logWrap.Dock = 'Fill'; $logWrap.BackColor = $Pal.Console; $logWrap.Padding = New-Object System.Windows.Forms.Padding(12, 10, 4, 10)
$content.Controls.Add($logWrap)
$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true; $log.ReadOnly = $true; $log.ScrollBars = 'Vertical'; $log.WordWrap = $true; $log.BorderStyle = 'None'; $log.Dock = 'Fill'
$log.BackColor = $Pal.Console; $log.ForeColor = $Pal.ConsoleInk
$logWrap.Controls.Add($log)
$list = New-Object System.Windows.Forms.ListView
$list.View = 'Details'; $list.FullRowSelect = $true; $list.BorderStyle = 'None'; $list.HeaderStyle = 'Nonclickable'; $list.Dock = 'Fill'; $list.BackColor = $Pal.Card; $list.Visible = $false
Set-Font $list 9
[void]$list.Columns.Add('', 110); [void]$list.Columns.Add('', 230); [void]$list.Columns.Add('', 480)
$content.Controls.Add($list)

$lblFoot = New-Lbl $form 24 612 852 32 8.5 'Regular' $Pal.FootInk
$lblFoot.BackColor = $Pal.Bg

# ------------------------------------------------------------------------------------------ text, tabs, state
$script:tab = 'log'
$script:status = $null
$script:statusLoaded = $false
$script:busy = $false
function Show-Tab([string]$Which) {
    $script:tab = $Which
    $logWrap.Visible = ($Which -eq 'log'); $list.Visible = ($Which -eq 'check')
    $content.BackColor = $(if ($Which -eq 'log') { $Pal.Console } else { $Pal.Line })
    $tabLog.ForeColor = $(if ($Which -eq 'log') { $Pal.Ink } else { $Pal.Muted })
    $tabCheck.ForeColor = $(if ($Which -eq 'check') { $Pal.Ink } else { $Pal.Muted })
    $act = $(if ($Which -eq 'log') { $tabLog } else { $tabCheck })
    $tabLine.Location = New-Object System.Drawing.Point($act.Left, ($act.Bottom + 2)); $tabLine.Width = $act.Width
}
function Apply-Texts {
    $log.Font = $(if ($script:lang -eq 'zh') { New-Object System.Drawing.Font('Microsoft YaHei UI', ([single](9 * $script:fontMul))) } else { New-Object System.Drawing.Font('Consolas', ([single](9.5 * $script:fontMul))) })
    $form.Text = (T 'appName') + ' - RTX 4090'
    $lblTitle.Text = T 'title'; $lblSub.Text = (T 'subtitle') -f $Manifest.version
    $segZh.BackColor = $(if ($script:lang -eq 'zh') { $Pal.Card } else { $Pal.HeadLine }); $segZh.ForeColor = $(if ($script:lang -eq 'zh') { $Pal.Ink } else { $Pal.HeadMuted })
    $segEn.BackColor = $(if ($script:lang -eq 'en') { $Pal.Card } else { $Pal.HeadLine }); $segEn.ForeColor = $(if ($script:lang -eq 'en') { $Pal.Ink } else { $Pal.HeadMuted })
    $lblTgl.Text = T 'tglLabel'
    $tileT[0].Text = T 'tInstall'; $tileT[1].Text = T 'tFiles'; $tileT[2].Text = T 'tProfile'; $tileT[3].Text = T 'tVersion'
    $btnCheck.Text = T 'bCheck'; $btnInstall.Text = T 'bInstall'; $btnReenroll.Text = T 'bReenroll'; $btnLogs.Text = T 'bLogs'; $btnUninstall.Text = T 'bUninstall'
    $tabLog.Text = T 'tabLog'; $tabCheck.Text = T 'tabCheck'
    $tabCheck.Left = $tabLog.Right + [int](22 * $script:sf)
    $list.Columns[0].Text = T 'cStatus'; $list.Columns[1].Text = T 'cName'; $list.Columns[2].Text = T 'cDetail'
    $lblFoot.Text = T 'footer'
    Show-Tab $script:tab
}
function Fmt-Time([string]$t) { if ($t) { return $t.Replace('T', ' ') }; return '' }
function Set-Hero([string]$State, [string]$Title, [string]$Sub) {
    $script:dotColor = switch ($State) { 'ok' { $Pal.Ok } 'bad' { $Pal.Bad } 'warn' { $Pal.Warn } default { $Pal.Idle } }
    $lblHero.ForeColor = switch ($State) { 'ok' { $Pal.OkInk } 'bad' { $Pal.BadInk } default { $Pal.Ink } }
    $lblHero.Text = $Title; $lblHeroSub.Text = $Sub
    $dot.Invalidate()
}
function Apply-Enabled {
    $idle = -not $script:busy
    $inst = [bool]($script:status -and $script:status.installed)
    Set-BtnEnabled $btnCheck $idle
    Set-BtnEnabled $btnInstall ($idle -and $script:statusLoaded -and -not $inst)
    Set-BtnEnabled $btnReenroll ($idle -and $inst)
    Set-BtnEnabled $btnLogs ($idle -and $inst)
    Set-BtnEnabled $btnUninstall ($idle -and $inst)
    $script:tglEnabled = ($idle -and $inst)
    $tgl.Cursor = $(if ($script:tglEnabled) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default })
    $tgl.Invalidate()
}
function Render-Status {
    $s = $script:status
    if (-not $script:statusLoaded) { Set-Hero 'idle' (T 'heroLoading') '' }
    elseif (-not $s) { Set-Hero 'bad' (T 'statusFail') '' }
    elseif (-not $s.installed) { Set-Hero 'idle' (T 'heroNotInstalled') (T 'notInstalledSub') }
    else {
        $sw = switch ($s.switch) { 'on' { T 'swOn' } 'off' { T 'swOff' } 'on-not-first' { T 'swNotFirst' } default { '' } }
        $lr = $s.lastRun
        $hint = $(if ($s.switch -eq 'on') { T 'restartHint' } else { '' })
        if (-not $lr) { if ($s.switch -eq 'on') { Set-Hero 'warn' (T 'heroPending') ($sw + "`r`n" + (T 'noRun')) } else { Set-Hero 'idle' (T 'heroLocked') ($sw + "`r`n" + (T 'noRun')) } }
        elseif ($lr.thisBoot -and $lr.unlocked) { Set-Hero 'ok' (T 'heroUnlocked') ($sw + "`r`n" + ((T 'runThis') -f (Fmt-Time $lr.time))) }
        elseif ($lr.thisBoot) { Set-Hero 'bad' (T 'heroFailed') ($sw + "`r`n" + ((T 'runFailed') -f (Fmt-Time $lr.time), $lr.stage)) }
        else { Set-Hero 'idle' (T 'heroLocked') ($sw + "`r`n" + ((T 'runEarlier') -f (Fmt-Time $lr.time)) + $hint) }
    }
    $script:tglOn = [bool]($s -and $s.switch -eq 'on')
    $state = $(if (-not ($s -and $s.installed)) { T 'tglNA' } elseif ($s.switch -eq 'on') { T 'tglOn' } elseif ($s.switch -eq 'on-not-first') { T 'tglNotFirst' } else { T 'tglOff' })
    $lblTglNote.Text = $state + '  ·  ' + (T 'applies')
    if ($s -and $s.installed) {
        $tileV[0].Text = (T 'vInstalled') -f $(if ($s.mode -eq 'usb') { T 'modeUsb' } else { T 'modePart' }); $tileV[0].ForeColor = $Pal.Ink
        $tileV[1].Text = $(if ($s.filesOk) { T 'vComplete' } else { T 'vIncomplete' }); $tileV[1].ForeColor = $(if ($s.filesOk) { $Pal.Ink } else { $Pal.BadInk })
        $tileV[2].Text = $(if ($s.enrolled) { T 'vEnrolled' } else { T 'vNotEnrolled' }); $tileV[2].ForeColor = $Pal.Ink
    } else {
        $tileV[0].Text = $(if ($s) { T 'vNotInstalled' } else { '—' }); $tileV[0].ForeColor = $Pal.Muted
        $tileV[1].Text = '—'; $tileV[2].Text = '—'; $tileV[1].ForeColor = $Pal.Muted; $tileV[2].ForeColor = $Pal.Muted
    }
    $tileV[3].Text = $(if ($s -and $s.version) { [string]$s.version } else { [string]$Manifest.version })
    Apply-Enabled
}

function Append-Log([string]$Line) {
    if ($Line) { $log.AppendText($Line); $log.SelectionStart = $log.TextLength; $log.ScrollToCaret() }
}
function Set-Busy([bool]$Busy) {
    $script:busy = $Busy
    $lblBusy.Visible = $Busy; $lblBusy.Text = '●  ' + (T 'busy')
    Apply-Enabled
}

# ------------------------------------------------------------------------------------------ run core.ps1 in a hidden process; its output goes to a file that a timer reads
$work = Join-Path $env:TEMP ('gpuunlock-gui-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $work | Out-Null
$script:proc = $null
$script:outFile = $null
$script:errFile = $null
$script:readPos = 0
$script:onDone = $null
$script:allText = ''
$script:spin = 0
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 400
function Read-New {
    if (-not $script:outFile -or -not (Test-Path -LiteralPath $script:outFile)) { return }
    $fs = [System.IO.File]::Open($script:outFile, 'Open', 'Read', 'ReadWrite')
    try {
        if ($fs.Length -gt $script:readPos) {
            $fs.Seek($script:readPos, 'Begin') | Out-Null
            $buf = New-Object byte[] ($fs.Length - $script:readPos)
            [void]$fs.Read($buf, 0, $buf.Length)
            $script:readPos = $fs.Length
            $chunk = [System.Text.Encoding]::UTF8.GetString($buf)
            $script:allText += $chunk
            $show = ($chunk -split "`r?`n" | Where-Object { $_ -and -not $_.StartsWith('@@JSON@@') }) -join "`r`n"
            if ($show) { Append-Log ($show + "`r`n") }
        }
    } finally { $fs.Close() }
}
$timer.Add_Tick({
    Read-New
    $script:spin = ($script:spin + 1) % 4
    $lblBusy.Text = '●  ' + (T 'busy') + ('.' * $script:spin)
    if ($script:proc -and $script:proc.HasExited) {
        $timer.Stop(); Read-New
        try { if ($script:errFile -and (Test-Path -LiteralPath $script:errFile)) { $err = (Get-Content -LiteralPath $script:errFile -Raw -ErrorAction SilentlyContinue); if ($err -and $err.Trim()) { Append-Log ($err.Trim() + "`r`n") } } } catch { }
        $code = $script:proc.ExitCode
        if ($null -eq $code) { $code = $(if ($script:allText -match '\[ERROR\]') { 1 } else { 0 }) }
        $cb = $script:onDone; $script:onDone = $null; $script:proc = $null
        Set-Busy $false
        if ($cb) { & $cb $code $script:allText }
    }
})
function Run-Core([string]$CoreArgs, [scriptblock]$Done) {
    $script:outFile = Join-Path $work ('out-' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.txt')
    $script:readPos = 0; $script:allText = ''; $script:onDone = $Done
    Set-Busy $true
    $script:errFile = $script:outFile + '.err'
    $argLine = '-NoProfile -ExecutionPolicy Bypass -File "' + $Core + '" ' + $CoreArgs + ' -Lang ' + $script:lang + ' -NoPause'
    $script:proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $argLine -WindowStyle Hidden -PassThru -RedirectStandardOutput $script:outFile -RedirectStandardError $script:errFile
    $null = $script:proc.Handle   # without this, ExitCode comes back empty and every success looks like a failure
    $timer.Start()
}
function Get-Json([string]$Raw) {
    $m = [regex]::Matches($Raw, '@@JSON@@(.+)')
    if ($m.Count -eq 0) { return $null }
    try { return ($m[$m.Count - 1].Groups[1].Value | ConvertFrom-Json) } catch { return $null }
}
function Refresh-Status {
    Run-Core 'status -Json' { param($code, $raw) $script:status = Get-Json $raw; $script:statusLoaded = $true; Render-Status }
}
function Ask([string]$Key, [string]$Icon = 'Question') { return [System.Windows.Forms.MessageBox]::Show((T $Key), (T 'appName'), 'YesNo', $Icon) }
function Restart-Soon { Start-Process -FilePath 'shutdown.exe' -ArgumentList '/r /t 10 /c "GPU Unlock: restarting"' -WindowStyle Hidden }

# ------------------------------------------------------------------------------------------ language switch
function Set-Lang([string]$L) {
    if ($L -eq $script:lang) { return }
    $script:lang = $L
    try { if (-not (Test-Path $PrefPath)) { New-Item -Path $PrefPath -Force | Out-Null }; Set-ItemProperty -Path $PrefPath -Name 'Lang' -Value $L } catch { }
    $form.SuspendLayout()
    Apply-Fonts; Apply-Texts; Render-Status
    $list.Items.Clear()   # check results came from core.ps1 in the other language; run the check again to refresh them
    $form.ResumeLayout()
    Append-Log ((T 'langChanged') + "`r`n")
}
$segZh.Add_Click({ Set-Lang 'zh' })
$segEn.Add_Click({ Set-Lang 'en' })
$tabLog.Add_Click({ Show-Tab 'log' })
$tabCheck.Add_Click({ Show-Tab 'check' })

# ------------------------------------------------------------------------------------------ actions
$tgl.Add_Click({
    if (-not $script:tglEnabled) { return }
    $script:turnOn = -not ($script:status -and $script:status.switch -eq 'on')
    Show-Tab 'log'; $log.Clear()
    Run-Core $(if ($script:turnOn) { 'enable' } else { 'disable' }) {
        param($c, $raw)
        Refresh-Status
        if ($c -eq 0) { if ((Ask $(if ($script:turnOn) { 'msgOn' } else { 'msgOff' })) -eq 'Yes') { Restart-Soon } }
    }
})
$btnCheck.Add_Click({
    $list.Items.Clear(); Show-Tab 'check'
    Run-Core 'check -Json' {
        param($c, $raw)
        $r = Get-Json $raw
        if ($r) {
            $n = @{ ok = 0; warn = 0; fail = 0 }
            foreach ($x in @($r)) {
                $st = [string]$x.status; if (-not $n.ContainsKey($st)) { $st = 'fail' }; $n[$st]++
                $it = New-Object System.Windows.Forms.ListViewItem(('●  ' + $(switch ($st) { 'ok' { T 'sOk' } 'warn' { T 'sWarn' } default { T 'sFail' } })))
                $it.UseItemStyleForSubItems = $false
                $it.ForeColor = $(switch ($st) { 'ok' { $Pal.Ok } 'warn' { $Pal.Warn } default { $Pal.Bad } })
                $s1 = $it.SubItems.Add([string]$x.name); $s1.ForeColor = $Pal.Ink
                $s2 = $it.SubItems.Add([string]$x.detail); $s2.ForeColor = $Pal.Muted
                [void]$list.Items.Add($it)
            }
            Append-Log (((T 'checkSummary') -f $n.ok, $n.warn, $n.fail) + "`r`n")
        }
        Refresh-Status
    }
})
$btnLogs.Add_Click({ Show-Tab 'log'; $log.Clear(); Append-Log ((T 'bootLogNote') + "`r`n"); Run-Core 'logs' { param($c, $raw) } })
$btnReenroll.Add_Click({ if ((Ask 'reenrollQ') -eq 'Yes') { Show-Tab 'log'; $log.Clear(); Run-Core 'reenroll' { param($c, $raw) Refresh-Status } } })
$btnUninstall.Add_Click({ if ((Ask 'uninstallQ' 'Warning') -eq 'Yes') { Show-Tab 'log'; $log.Clear(); Run-Core 'uninstall' { param($c, $raw) Refresh-Status } } })

# ------------------------------------------------------------------------------------------ install dialog
function New-InstallDialog($Cand) {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.AutoScaleMode = 'None'
    $dlg.Text = T 'dlgTitle'; $dlg.ClientSize = New-Object System.Drawing.Size(620, 486); $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.BackColor = $Pal.Card; $dlg.Font = F 9
    $hd = New-Lbl $dlg 22 16 576 30 13 'Bold' -NoTrack; $hd.Text = T 'dlgHead'
    $rP = New-Object System.Windows.Forms.RadioButton; $rP.Location = New-Object System.Drawing.Point(24, 58); $rP.Size = New-Object System.Drawing.Size(572, 24); $rP.Font = F 10 'Bold'; $rP.Text = T 'optPart'; $rP.Checked = $true
    $cP = New-Object System.Windows.Forms.ComboBox; $cP.DropDownStyle = 'DropDownList'; $cP.Location = New-Object System.Drawing.Point(46, 86); $cP.Size = New-Object System.Drawing.Size(550, 26); $cP.Font = F 9.5
    $nP = New-Lbl $dlg 46 116 550 40 8.5 'Regular' $Pal.Muted -NoTrack; $nP.Text = T 'optPartNote'
    $rU = New-Object System.Windows.Forms.RadioButton; $rU.Location = New-Object System.Drawing.Point(24, 164); $rU.Size = New-Object System.Drawing.Size(572, 24); $rU.Font = F 10 'Bold'; $rU.Text = T 'optUsb'
    $cU = New-Object System.Windows.Forms.ComboBox; $cU.DropDownStyle = 'DropDownList'; $cU.Location = New-Object System.Drawing.Point(46, 192); $cU.Size = New-Object System.Drawing.Size(550, 26); $cU.Font = F 9.5; $cU.Enabled = $false
    $nU = New-Lbl $dlg 46 222 550 22 8.5 'Regular' $Pal.Muted -NoTrack; $nU.Text = T 'optUsbNote'
    $box = New-Card $dlg 24 254 572 120 $Pal.Soft
    $st = New-Lbl $box 14 10 546 104 9 'Regular' $Pal.Ink -NoTrack; $st.Text = T 'steps'
    $chkEnable = New-Object System.Windows.Forms.CheckBox; $chkEnable.Location = New-Object System.Drawing.Point(24, 386); $chkEnable.Size = New-Object System.Drawing.Size(572, 22); $chkEnable.Font = F 9; $chkEnable.Text = T 'chkEnable'; $chkEnable.Checked = $true
    $chkRisk = New-Object System.Windows.Forms.CheckBox; $chkRisk.Location = New-Object System.Drawing.Point(24, 410); $chkRisk.Size = New-Object System.Drawing.Size(572, 22); $chkRisk.Font = F 9 'Bold'; $chkRisk.Text = T 'chkRisk'
    $ok = New-Btn $dlg 372 440 116 34 'primary' -NoTrack; $ok.Text = T 'bGo'; $ok.DialogResult = 'OK'
    $cancel = New-Btn $dlg 496 440 100 34 -NoTrack; $cancel.Text = T 'bCancel'; $cancel.DialogResult = 'Cancel'
    Set-BtnEnabled $ok $false
    $pLetters = New-Object System.Collections.ArrayList; $uLetters = New-Object System.Collections.ArrayList
    if ($Cand) {
        $first = $true
        foreach ($x in @($Cand.partition)) { [void]$cP.Items.Add((((T 'partItem') -f $x.Letter, $x.FreeGB) + $(if ($x.IsSystem) { T 'sysSuffix' } else { '' }) + $(if ($first) { T 'recSuffix' } else { '' }))); [void]$pLetters.Add([string]$x.Letter); $first = $false }
        foreach ($x in @($Cand.usb)) { [void]$cU.Items.Add(((T 'usbItem') -f $x.Letter, $x.Label, $x.FreeMB)); [void]$uLetters.Add([string]$x.Letter) }
    }
    if ($cP.Items.Count -gt 0) { $cP.SelectedIndex = 0 } else { [void]$cP.Items.Add((T 'noneFound')); $cP.SelectedIndex = 0; $rP.Enabled = $false; $cP.Enabled = $false; $rU.Checked = $true }
    if ($cU.Items.Count -gt 0) { $cU.SelectedIndex = 0; $cU.Enabled = $rU.Checked } else { [void]$cU.Items.Add((T 'noneFound')); $cU.SelectedIndex = 0; $rU.Enabled = $false; $cU.Enabled = $false }
    # these handlers fire after this function has returned, so they carry their own copies of the controls
    $okOn = $Pal.Primary; $okOff = $Pal.Disabled
    $rP.Add_CheckedChanged({ $cP.Enabled = $rP.Checked; $cU.Enabled = -not $rP.Checked }.GetNewClosure())
    $chkRisk.Add_CheckedChanged({ $go = $chkRisk.Checked -and ($rP.Enabled -or $rU.Enabled); $ok.Enabled = $go; $ok.BackColor = $(if ($go) { $okOn } else { $okOff }) }.GetNewClosure())
    foreach ($ctl in $rP, $cP, $rU, $cU, $chkEnable, $chkRisk) { $dlg.Controls.Add($ctl) }
    $dlg.AcceptButton = $ok; $dlg.CancelButton = $cancel
    $dlg.Scale((New-Object System.Drawing.SizeF([single]$script:sf, [single]$script:sf))); $dlg.ClientSize = New-Object System.Drawing.Size([int](620 * $script:sf), [int](486 * $script:sf))
    return @{ Form = $dlg; rP = $rP; cP = $cP; rU = $rU; cU = $cU; Enable = $chkEnable; PL = $pLetters; UL = $uLetters }
}
$btnInstall.Add_Click({
    Show-Tab 'log'; $log.Clear(); Append-Log ((T 'readingDisks') + "`r`n")
    Run-Core 'candidates -Json' {
        param($c, $raw)
        $d = New-InstallDialog (Get-Json $raw)
        $answer = $d.Form.ShowDialog($form)
        if ($answer -eq 'OK') {
            $argsText = 'install'
            if ($d.rP.Checked) { $argsText += ' -Mode partition -TargetVolume ' + $d.PL[$d.cP.SelectedIndex] }
            else { $argsText += ' -Mode usb -Drive ' + $d.UL[$d.cU.SelectedIndex] + ':' }
            if (-not $d.Enable.Checked) { $argsText += ' -NoEnable' }
            $d.Form.Dispose()
            $log.Clear()
            Run-Core $argsText {
                param($code, $raw2)
                Refresh-Status
                if ($code -eq 0) { if ((Ask 'installedQ' 'Information') -eq 'Yes') { Restart-Soon } }
                else { [System.Windows.Forms.MessageBox]::Show((T 'installFailed'), (T 'appName'), 'OK', 'Error') | Out-Null }
            }
        } else { $d.Form.Dispose(); Refresh-Status }
    }
})

# ------------------------------------------------------------------------------------------ start
$form.Scale((New-Object System.Drawing.SizeF([single]$script:sf, [single]$script:sf)))
$form.ClientSize = New-Object System.Drawing.Size([int](900 * $script:sf), [int](650 * $script:sf))
Apply-Texts
Render-Status
$form.Add_Shown({
    $list.Columns[0].Width = [int](110 * $script:sf); $list.Columns[1].Width = [int](230 * $script:sf)
    $list.Columns[2].Width = [int]($content.ClientSize.Width - $list.Columns[0].Width - $list.Columns[1].Width - 24 * $script:sf)
    $il = New-Object System.Windows.Forms.ImageList; $il.ImageSize = New-Object System.Drawing.Size(1, [int](26 * $script:sf)); $list.SmallImageList = $il
    Apply-Texts
    Append-Log ((T 'ready') + "`r`n")
    Refresh-Status
})
$form.Add_FormClosing({ try { $timer.Stop() } catch { }; try { Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue } catch { } })

if ($Snapshot) {
    function Save-Shot($Win, [string]$Path) {
        # the snapshot desktop can be smaller than the scaled window, so the client area is composed control by control
        $w = [int](($Win.Controls | ForEach-Object { $_.Right } | Measure-Object -Maximum).Maximum + 24 * $script:sf)
        $h = [int](($Win.Controls | ForEach-Object { $_.Bottom } | Measure-Object -Maximum).Maximum + 16 * $script:sf)
        $bmp = New-Object System.Drawing.Bitmap($w, $h)
        $g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear($Win.BackColor); $g.Dispose()
        for ($i = $Win.Controls.Count - 1; $i -ge 0; $i--) { $c = $Win.Controls[$i]; if ($c.Visible) { $c.DrawToBitmap($bmp, $c.Bounds) } }
        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    }
    $script:snapStage = 0
    $snapTimer = New-Object System.Windows.Forms.Timer; $snapTimer.Interval = 600
    $snapTimer.Add_Tick({
        if ($script:busy) { return }
        switch ($script:snapStage) {
            0 { if ($script:statusLoaded) { $script:snapStage = 1 } }
            1 { Save-Shot $form $Snapshot; $script:snapStage = 2; if ($SnapshotCheck) { $btnCheck.PerformClick() } }
            2 {
                if ($SnapshotCheck) { Save-Shot $form ($Snapshot -replace '\.png$', '-check.png') }
                $script:snapStage = 3
                if ($SnapshotDialog) { Run-Core 'candidates -Json' { param($c, $raw) $d = New-InstallDialog (Get-Json $raw); $d.Form.Show(); [System.Windows.Forms.Application]::DoEvents(); Save-Shot $d.Form $SnapshotDialog; Set-Content -LiteralPath ($SnapshotDialog + '.txt') -Encoding UTF8 -Value ('partition: ' + $d.cP.Text + ' | usb: ' + $d.cU.Text + ' | letters: ' + ($d.PL -join ',')); $d.Form.Close() } }
            }
            3 { Set-Lang $(if ($script:lang -eq 'zh') { 'en' } else { 'zh' }); [System.Windows.Forms.Application]::DoEvents(); Save-Shot $form ($Snapshot -replace '\.png$', '-switched.png'); $snapTimer.Stop(); $form.Close() }
        }
    })
    $snapTimer.Start()
}
if ($Snapshot) { [System.Windows.Forms.Application]::Run($form) } else { [void]$form.ShowDialog() }   # a modal window is refused in a non-interactive session
