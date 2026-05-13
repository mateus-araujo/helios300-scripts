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
    ThrottlestopExe  = "C:\Throttlestop\Throttlestop.exe"
    AfterburnerExe   = "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe"
    NBFCConfigPath   = "${env:ProgramFiles(x86)}\NoteBook FanControl\config.json"
    ProfileDir       = "$PSScriptRoot\profiles"
}

# ─── Carrega caminhos personalizados se existirem ───
$customCfg = "$PSScriptRoot\install-paths.ps1"
if (Test-Path $customCfg) { . $customCfg }

# ─── Funções ───

function Set-ThrottlestopProfile {
    param([string]$ProfileName)
    $src = "$($config.ProfileDir)\throttlestop\$ProfileName.ini"
    $dst = "$($config.ThrottlestopPath)\Throttlestop.ini"
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Host "  ✓ Throttlestop: $ProfileName" -ForegroundColor Green
        Stop-Process -Name "Throttlestop" -Force -ErrorAction SilentlyContinue
        if (Test-Path $config.ThrottlestopExe) {
            Start-Process $config.ThrottlestopExe
        }
    } else {
        Write-Host "  ✗ Throttlestop profile not found: $src" -ForegroundColor Red
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

function Set-NBFCFanProfile {
    param([string]$ProfileName)
    $src = "$($config.ProfileDir)\nbfc\$ProfileName.json"
    $dst = $config.NBFCConfigPath
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Restart-Service nbfc -ErrorAction SilentlyContinue
        if ($?) {
            Write-Host "  ✓ Fans (NBFC): $ProfileName" -ForegroundColor Green
        } else {
            Write-Host "  ! NBFC service not available" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✗ Fan profile not found: $src" -ForegroundColor Red
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
        Write-Host "  1. 🎮  Gaming Mode"
        Write-Host "  2. 📖  Silent Mode"
        Write-Host "  3. 🔄  Auto Mode (default)"
        Write-Host "  0. ❌  Exit"
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
        Write-Host "`n🎮 Gaming Mode:`n" -ForegroundColor Magenta
        Set-ThrottlestopProfile "gaming"
        Start-Sleep -Seconds 2
        Set-AfterburnerProfile "2"
        Start-Sleep -Seconds 1
        Set-NBFCFanProfile "gaming"
        Write-Host "`n✅ Done! Expect 70-80°C in games (was 90-95°C)`n" -ForegroundColor Green
    }
    "silent" {
        Write-Host "`n📖 Silent Mode:`n" -ForegroundColor Blue
        Set-ThrottlestopProfile "silent"
        Start-Sleep -Seconds 2
        Set-AfterburnerProfile "3"
        Start-Sleep -Seconds 1
        Set-NBFCFanProfile "silent"
        Write-Host "`n✅ Silent mode active. Fans near-inaudible.`n" -ForegroundColor Green
    }
    "auto" {
        Write-Host "`n🔄 Auto Mode (factory defaults):`n" -ForegroundColor Yellow
        Stop-Process -Name "Throttlestop" -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Throttlestop stopped" -ForegroundColor Green
        Set-AfterburnerProfile "1"
        Stop-Service nbfc -ErrorAction SilentlyContinue
        Set-Service nbfc -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  ✓ NBFC stopped (PredatorSense controls fans)" -ForegroundColor Green
        Write-Host "`n✅ All back to factory defaults.`n" -ForegroundColor Green
    }
}
