<#
.SYNOPSIS
  Configura os caminhos dos programas no seu PC.
  Edite este arquivo com os caminhos corretos antes de executar.
#>

$config.ThrottlestopPath = "$env:LOCALAPPDATA\Throttlestop"
$config.ThrottlestopExe  = "C:\Throttlestop\Throttlestop.exe"
$config.AfterburnerExe   = "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe"
$config.FanControlPath   = "$env:LOCALAPPDATA\FanControl"
$config.FanControlExe    = "C:\FanControl\FanControl.exe"
