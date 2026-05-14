<#
.SYNOPSIS
  Alterna entre modos Gaming, Silent e Auto no Helios 300.
.PARAMETER Mode
  "gaming", "silent" ou "auto"
.EXAMPLE
  .\toggle-mode.ps1 -Mode gaming
#>

param(
    [ValidateSet("gaming", "silent", "auto")]
    [string]$Mode = ""
)

# ─── Caminhos padrão ───
$config = @{
    ThrottlestopPath = "$env:LOCALAPPDATA\Throttlestop"
    ThrottlestopExe  = "C:\ThrottleStop\ThrottleStop.exe"
    ThrottlestopIni  = "C:\ThrottleStop\ThrottleStop.ini"
    AfterburnerExe   = "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe"
}

# ─── Carrega caminhos personalizados se existirem ───
$customCfg = "$PSScriptRoot\install-paths.ps1"
if (Test-Path $customCfg) { . $customCfg }

# ─── Tabela de perfis TS 9.7 ───
$tsProfiles = @{
    gaming = @{
        Profile   = 0
        EnPerfPref = 84
        DutyCycle  = 40
        CoreMV     = -100
        CacheMV    = -90
        Payload    = "0x1700"
    }
    silent = @{
        Profile   = 1
        EnPerfPref = 128
        DutyCycle  = 28
        CoreMV     = -80
        CacheMV    = -70
        Payload    = "0x1700"
    }
}

# ─── Codifica offset mV para FIVR hex (TS 9.7) ───
function ConvertTo-FIVRHex {
    param([int]$Millivolts)
    $dec = [int][Math]::Round($Millivolts * 32)
    if ($dec -ge 0) { return "0x{0:X8}" -f $dec }
    $twos = 0x10000 + $dec
    return "0x{0:X4}0000" -f $twos
}

# ─── Funções ───

function Set-ThrottlestopProfile {
    param([string]$ProfileName)
    $profile = $tsProfiles[$ProfileName]
    if (-not $profile) {
        Write-Host "  ✗ Unknown Throttlestop profile: $ProfileName" -ForegroundColor Red
        return
    }
    $ini = $config.ThrottlestopIni
    if (-not (Test-Path $ini)) {
        Write-Host "  ✗ ThrottleStop.ini not found at $ini" -ForegroundColor Red
        return
    }

    $content = Get-Content $ini -Raw
    $coreHex = ConvertTo-FIVRHex -Millivolts $profile.CoreMV
    $cacheHex = ConvertTo-FIVRHex -Millivolts $profile.CacheMV

    $lines = $content -split "`r?`n"
    $newLines = @()
    $inThrottleStop = $false

    foreach ($line in $lines) {
        if ($line -match '^\[ThrottleStop\]') { $inThrottleStop = $true }
        elseif ($line -match '^\[.*\]') { $inThrottleStop = $false }

        if ($inThrottleStop) {
            if ($line -match '^Profile=') { $line = "Profile=$($profile.Profile)" }
            elseif ($line -match '^EnPerfPref0=') { $line = "EnPerfPref0=$($profile.EnPerfPref)" }
            elseif ($line -match '^DutyCycle1=') { $line = "DutyCycle1=$($profile.DutyCycle)" }
            elseif ($line -match '^FIVRVoltage00=') { $line = "FIVRVoltage00=$coreHex" }
            elseif ($line -match '^FIVRVoltage20=') { $line = "FIVRVoltage20=$cacheHex" }
            elseif ($line -match '^UnlockVoltage00=') { $line = "UnlockVoltage00=1" }
            elseif ($line -match '^UnlockVoltage20=') { $line = "UnlockVoltage20=1" }
            elseif ($line -match '^Payload1=') { $line = "Payload1=$($profile.Payload)" }
        }
        $newLines += $line
    }

    $newContent = $newLines -join "`r`n"
    $newContent = $newContent -replace '(?<=^ProfileName1=).*', 'Gaming'
    $newContent = $newContent -replace '(?<=^ProfileName2=).*', 'Silent'

    Set-Content $ini $newContent -NoNewline -Encoding Default
    Write-Host "  ✓ ThrottleStop: $ProfileName (Core $($profile.CoreMV)mV, Cache $($profile.CacheMV)mV)" -ForegroundColor Green

    Stop-Process -Name "Throttlestop" -Force -ErrorAction SilentlyContinue
    if (Test-Path $config.ThrottlestopExe) {
        Start-Process $config.ThrottlestopExe
    }
}

function Set-AfterburnerProfile {
    param([string]$ProfileNum)
    if (Test-Path $config.AfterburnerExe) {
        $proc = Get-Process -Name "MSIAfterburner" -ErrorAction SilentlyContinue
        if (-not $proc) {
            Start-Process $config.AfterburnerExe
            Start-Sleep -Seconds 3
        }
        Start-Process $config.AfterburnerExe -ArgumentList "/Profile$ProfileNum"
        Write-Host "  ✓ MSI Afterburner: perfil $ProfileNum" -ForegroundColor Green
    } else {
        Write-Host "  ! Afterburner not found, switch manually" -ForegroundColor Yellow
    }
}

# ─── Menu interativo ───
if (-not $Mode) {
    do {
        Clear-Host
        Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Helios 300 - Thermal Management" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  1.  Gaming Mode"
        Write-Host "  2.  Silent Mode"
        Write-Host "  3.  Auto Mode (default)"
        Write-Host "  0.  Exit"
        Write-Host ""
        $choice = Read-Host "Choose an option"
        switch ($choice) {
            "1" { $Mode = "gaming"; break }
            "2" { $Mode = "silent"; break }
            "3" { $Mode = "auto"; break }
            "0" { exit }
        }
    } while (-not $Mode)
}

# ─── Aplica ───
Clear-Host
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Applying Mode: $Mode" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

switch ($Mode) {
    "gaming" {
        Write-Host "`nGaming Mode:`n" -ForegroundColor Magenta
        Set-ThrottlestopProfile "gaming"
        Start-Sleep -Seconds 2
        Set-AfterburnerProfile "2"
        Write-Host "`nDone! Expect 70-80C in games (was 90-95C)`n" -ForegroundColor Green
    }
    "silent" {
        Write-Host "`nSilent Mode:`n" -ForegroundColor Blue
        Set-ThrottlestopProfile "silent"
        Start-Sleep -Seconds 2
        Set-AfterburnerProfile "3"
        Write-Host "`nSilent mode active. Fans near-inaudible.`n" -ForegroundColor Green
    }
    "auto" {
        Write-Host "`nAuto Mode (factory defaults):`n" -ForegroundColor Yellow
        Stop-Process -Name "Throttlestop" -Force -ErrorAction SilentlyContinue
        Write-Host "  Throttlestop stopped" -ForegroundColor Green
        Set-AfterburnerProfile "1"
        Write-Host "  PredatorSense controls fans" -ForegroundColor Green
        Write-Host "`nAll back to factory defaults.`n" -ForegroundColor Green
    }
}
