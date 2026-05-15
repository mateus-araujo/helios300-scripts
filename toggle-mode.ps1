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
        Profile        = 0
        EnPerfPref     = 84
        DutyCycle      = 35
        Payload        = "0x1700"
        SpeedShiftMax  = 26
        SpeedShiftMin  = 1
        ProchotOffset  = 20
    }
    silent = @{
        Profile        = 1
        EnPerfPref     = 128
        DutyCycle      = 28
        Payload        = "0x1700"
        SpeedShiftMax  = 20
        SpeedShiftMin  = 1
        ProchotOffset  = 25
    }
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
            elseif ($line -match '^Payload1=') { $line = "Payload1=$($profile.Payload)" }
            elseif ($line -match "^SpeedShiftMaxMin$($profile.Profile)=") {
                $line = "SpeedShiftMaxMin$($profile.Profile)=0x{0:X2}{1:X2}" -f $profile.SpeedShiftMax, $profile.SpeedShiftMin
            }
            elseif ($line -match "^PROCHOT_Offset$($profile.Profile)=") {
                $line = "PROCHOT_Offset$($profile.Profile)=0x{0:X}" -f $profile.ProchotOffset
            }
        }
        $newLines += $line
    }

    $newContent = $newLines -join "`r`n"
    $newContent = $newContent -replace '(?<=^ProfileName1=).*', 'Gaming'
    $newContent = $newContent -replace '(?<=^ProfileName2=).*', 'Silent'

    $newContent = [regex]::Replace($newContent, '(?m)(?<=^Options1=)0x[0-9A-Fa-f]+', {
        param($m)
        "0x{0:X8}" -f ([int]$m.Value -bor 0x400000)
    })

    Set-Content $ini $newContent -NoNewline -Encoding Default
    Write-Host "  ✓ ThrottleStop: $ProfileName" -ForegroundColor Green

    Stop-Process -Name "Throttlestop" -Force -ErrorAction SilentlyContinue
    if (Test-Path $config.ThrottlestopExe) {
        Start-Process $config.ThrottlestopExe -ArgumentList "/Log"
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
        Write-Host "`nDone! PROCHOT offset caps temp at ~80°C" -ForegroundColor Green
        Write-Host "  SpeedShift max 26 · DutyCycle 35`n" -ForegroundColor Green
    }
    "silent" {
        Write-Host "`nSilent Mode:`n" -ForegroundColor Blue
        Set-ThrottlestopProfile "silent"
        Start-Sleep -Seconds 2
        Set-AfterburnerProfile "3"
        Write-Host "`nSilent mode active.`n" -ForegroundColor Green
    }
    "auto" {
        Write-Host "`nAuto Mode (factory defaults):`n" -ForegroundColor Yellow
        Stop-Process -Name "Throttlestop" -Force -ErrorAction SilentlyContinue
        Write-Host "  Throttlestop stopped" -ForegroundColor Green
        Set-AfterburnerProfile "1"
        Write-Host "`nAll back to factory defaults.`n" -ForegroundColor Green
    }
}
