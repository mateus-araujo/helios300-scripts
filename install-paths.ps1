<#
.SYNOPSIS
  Configura os caminhos dos programas no seu PC.
  Edite este arquivo com os caminhos corretos antes de executar.
#>

$config.ThrottlestopPath = "C:\ThrottleStop"
$config.ThrottlestopExe  = "C:\ThrottleStop\ThrottleStop.exe"
$config.AfterburnerExe   = "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe"

# FanControl instalado em Program Files (x86)
$config.FanControlCfgDir  = "${env:ProgramFiles(x86)}\FanControl\Configurations"
$config.FanControlExe     = "${env:ProgramFiles(x86)}\FanControl\FanControl.exe"
