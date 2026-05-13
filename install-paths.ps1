<#
.SYNOPSIS
  Configura os caminhos dos programas no seu PC.
  Edite este arquivo com os caminhos corretos antes de executar.
#>

$config.ThrottlestopPath = "$env:LOCALAPPDATA\Throttlestop"
$config.ThrottlestopExe  = "C:\Throttlestop\Throttlestop.exe"
$config.AfterburnerExe   = "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe"
$config.NBFCConfigPath   = "${env:ProgramFiles(x86)}\NoteBook FanControl\config.json"
