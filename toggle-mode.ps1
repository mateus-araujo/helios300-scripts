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
    [string]$Mode = "",
    [ValidateSet("gaming", "silent")]
    [string]$RegisterProfile = ""
)

# ─── Caminhos padrão ───
$config = @{
    ThrottlestopPath = "$env:LOCALAPPDATA\Throttlestop"
    ThrottlestopExe  = "C:\ThrottleStop\ThrottleStop.exe"
    ThrottlestopIni  = "C:\ThrottleStop\ThrottleStop.ini"
    AfterburnerExe   = "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe"
    FanControlCfgDir  = "${env:ProgramFiles(x86)}\FanControl\Configurations"
    FanControlExe    = "${env:ProgramFiles(x86)}\FanControl\FanControl.exe"
    ProfileDir       = "$PSScriptRoot\profiles"
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
    $foundProfile = $false
    $foundEPP = $false
    $foundDuty = $false
    $foundCore = $false
    $foundCache = $false
    $foundUnlockCore = $false
    $foundUnlockCache = $false
    $foundPayload = $false

    foreach ($line in $lines) {
        if ($line -match '^\[ThrottleStop\]') { $inThrottleStop = $true }
        elseif ($line -match '^\[.*\]') { $inThrottleStop = $false }

        if ($inThrottleStop) {
            if ($line -match '^Profile=') {
                $line = "Profile=$($profile.Profile)"
                $foundProfile = $true
            }
            elseif ($line -match '^EnPerfPref0=') {
                $line = "EnPerfPref0=$($profile.EnPerfPref)"
                $foundEPP = $true
            }
            elseif ($line -match '^DutyCycle1=') {
                $line = "DutyCycle1=$($profile.DutyCycle)"
                $foundDuty = $true
            }
            elseif ($line -match '^FIVRVoltage00=') {
                $line = "FIVRVoltage00=$coreHex"
                $foundCore = $true
            }
            elseif ($line -match '^FIVRVoltage20=') {
                $line = "FIVRVoltage20=$cacheHex"
                $foundCache = $true
            }
            elseif ($line -match '^UnlockVoltage00=') {
                $line = "UnlockVoltage00=1"
                $foundUnlockCore = $true
            }
            elseif ($line -match '^UnlockVoltage20=') {
                $line = "UnlockVoltage20=1"
                $foundUnlockCache = $true
            }
            elseif ($line -match '^Payload1=') {
                $line = "Payload1=$($profile.Payload)"
                $foundPayload = $true
            }
        }
        $newLines += $line
    }

    $newContent = $newLines -join "`r`n"

    # Garante que os perfis estão nomeados corretamente
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

function Set-FanControlProfile {
    param([string]$ProfileName)
    $src = "$($config.ProfileDir)\fancontrol\$ProfileName.json"
    $dstDir = $config.FanControlCfgDir
    $dstFile = "$dstDir\$ProfileName.json"

    if (-not (Test-Path $src)) {
        Write-Host "  ! FanControl profile not found: $src" -ForegroundColor Yellow
        Write-Host "    Configure o FanControl manualmente e use a opção 4/5 do menu" -ForegroundColor Yellow
        Write-Host "    para registrar o perfil atual." -ForegroundColor Yellow
        return
    }

    # Check if profile has any controls or curves configured
    try {
        $profileJson = Get-Content $src -Raw | ConvertFrom-Json
        $hasControls = ($profileJson.FanControl.Controls.Count -gt 0)
        $hasCurves = ($profileJson.FanControl.FanCurves.Count -gt 0)
    } catch {
        $hasControls = $false
        $hasCurves = $false
    }

    if (-not $hasControls -and -not $hasCurves) {
        Write-Host "  ! Perfil '$ProfileName' não tem curvas de fan configuradas." -ForegroundColor Yellow
        Write-Host "    Abra o FanControl, configure as curvas manualmente," -ForegroundColor Yellow
        Write-Host "    depois use a opção Register (4/5) no menu para salvar." -ForegroundColor Yellow
    }

    $null = New-Item -ItemType Directory -Path $dstDir -Force -ErrorAction SilentlyContinue
    try {
        Copy-Item $src $dstFile -Force -ErrorAction Stop
    } catch {
        Write-Host "  ! Não foi possível copiar o perfil para $dstFile" -ForegroundColor Yellow
        Write-Host "    Execute o PowerShell como Administrador ou copie manualmente:" -ForegroundColor Yellow
        Write-Host "    Copy-Item '$src' '$dstFile'" -ForegroundColor Yellow
        return
    }

    Stop-Process -Name "FanControl" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500

    if (Test-Path $config.FanControlExe) {
        Start-Process $config.FanControlExe -WorkingDirectory $config.FanControlCfgDir -ArgumentList "-c", "$ProfileName.json"
        Write-Host "  ✓ Fans (FanControl): $ProfileName" -ForegroundColor Green
        if (-not $hasControls -and -not $hasCurves) {
            Write-Host "  ! Perfil vazio - configure curvas no FanControl e registre." -ForegroundColor Yellow
        } elseif (-not $hasControls) {
            Write-Host "  ! Curvas salvas mas sem controles - execute FanControl como Admin" -ForegroundColor Yellow
            Write-Host "    para adicionar controles de fan e re-registrar." -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✓ Fan config copied: $ProfileName" -ForegroundColor Green
        Write-Host "  ! FanControl not found, start it manually" -ForegroundColor Yellow
    }
}

function Register-FanControlProfile {
    param([string]$ProfileName)
    $src = "$($config.FanControlCfgDir)\userConfig.json"
    $dst = "$($config.ProfileDir)\fancontrol\$ProfileName.json"
    if (-not (Test-Path $src)) {
        Write-Host "  ✗ FanControl config not found. Open FanControl first." -ForegroundColor Red
        return
    }
    try {
        $cfg = Get-Content $src -Raw | ConvertFrom-Json
        $hasControls = ($cfg.FanControl.Controls.Count -gt 0)
        $hasCurves = ($cfg.FanControl.FanCurves.Count -gt 0)
        if (-not $hasControls -and -not $hasCurves) {
            Write-Host "  ! A configuração atual não tem curvas de fan." -ForegroundColor Yellow
            Write-Host "    Configure as curvas no FanControl e tente novamente." -ForegroundColor Yellow
            return
        }
        if ($hasControls) {
            Write-Host "  ✓ Perfil '$ProfileName' salvo com $($cfg.FanControl.Controls.Count) controle(s)!" -ForegroundColor Green
        } else {
            Write-Host "  ✓ Perfil '$ProfileName' salvo com $($cfg.FanControl.FanCurves.Count) curva(s)!" -ForegroundColor Green
            Write-Host "  ! Nenhum controle de fan detectado - execute o FanControl como" -ForegroundColor Yellow
            Write-Host "    Administrador para detectar as fans e adicionar controles." -ForegroundColor Yellow
        }
        Copy-Item $src $dst -Force
    } catch {
        Write-Host "  ✗ Erro ao ler userConfig.json: $_" -ForegroundColor Red
    }
}

# ─── Register mode (salva config atual do FanControl como perfil) ───
if ($RegisterProfile) {
    Register-FanControlProfile $RegisterProfile
    exit
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
        Write-Host "  4.  Register current FanControl config as Gaming"
        Write-Host "  5.  Register current FanControl config as Silent"
        Write-Host "  0.  Exit"
        Write-Host ""
        $choice = Read-Host "Choose an option"
        switch ($choice) {
            "1" { $Mode = "gaming"; break }
            "2" { $Mode = "silent"; break }
            "3" { $Mode = "auto"; break }
            "4" { Register-FanControlProfile "gaming"; $Mode = ""; continue }
            "5" { Register-FanControlProfile "silent"; $Mode = ""; continue }
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
        Start-Sleep -Seconds 1
        Set-FanControlProfile "gaming"
        Write-Host "`nDone! Expect 70-80C in games (was 90-95C)`n" -ForegroundColor Green
    }
    "silent" {
        Write-Host "`nSilent Mode:`n" -ForegroundColor Blue
        Set-ThrottlestopProfile "silent"
        Start-Sleep -Seconds 2
        Set-AfterburnerProfile "3"
        Start-Sleep -Seconds 1
        Set-FanControlProfile "silent"
        Write-Host "`nSilent mode active. Fans near-inaudible.`n" -ForegroundColor Green
    }
    "auto" {
        Write-Host "`nAuto Mode (factory defaults):`n" -ForegroundColor Yellow
        Stop-Process -Name "Throttlestop" -Force -ErrorAction SilentlyContinue
        Write-Host "  Throttlestop stopped" -ForegroundColor Green
        Set-AfterburnerProfile "1"
        Stop-Process -Name "FanControl" -Force -ErrorAction SilentlyContinue
        Write-Host "  FanControl stopped (PredatorSense controls fans)" -ForegroundColor Green
        Write-Host "`nAll back to factory defaults.`n" -ForegroundColor Green
    }
}
