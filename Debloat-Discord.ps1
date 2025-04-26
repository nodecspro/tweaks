<#
.SYNOPSIS
    Optimized Debloat script for Discord: removes cache, modules, language packs, cleans old versions, removes log files, sets DPI override, and conditionally restarts Discord.
.DESCRIPTION
    - Requires administrator privileges.
    - Cleans up old Discord app-* folders, keeps only the latest.
    - Removes any *.log in %LOCALAPPDATA%\Discord.
    - Removes specified modules, cache, unwanted locales, and the SquirrelTemp folder.
    - Keeps only en-US and ru language packs.
    - Applies DPI override in registry, creating key if necessary.
    - If Discord was running at script start, restarts it detached after debloat.
    - Catches errors and waits for key press before exit.
USAGE:
    Run in elevated PowerShell:
      PowerShell -ExecutionPolicy Bypass -File .\Debloat-Discord.ps1
#>

# Stop on any error
$ErrorActionPreference = 'Stop'

try {
    # Administrator check
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        throw 'This script must be run as Administrator.'
    }
    Write-Host '=== Starting Debloat ==='

    # Detect if Discord is running at script start
    $wasRunning = (Get-Process -Name Discord -ErrorAction SilentlyContinue) -ne $null

    # Locate all Discord installations and remove outdated versions
    $installRoot = Join-Path $env:LOCALAPPDATA 'Discord'
    $allApps = Get-ChildItem -Path $installRoot -Directory -Filter 'app-*' | Sort-Object Name -Descending
    if ($allApps.Count -lt 1) {
        throw 'No Discord app-* folders found.'
    }
    # Keep only latest
    $latest = $allApps[0]
    $outdated = $allApps | Select-Object -Skip 1
    foreach ($old in $outdated) {
        Remove-Item -Path $old.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed outdated version: $($old.Name)"
    }
    $basePath = $latest.FullName
    Write-Host "Using latest installation: $($latest.Name)"

    # Remove Discord log files
    Write-Host 'Removing Discord log files...'
    Get-ChildItem -Path $installRoot -Filter '*.log' -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host 'Log files removed.'

    # Remove SquirrelTemp folder
    $squirrelPath = Join-Path $installRoot 'packages\SquirrelTemp'
    if (Test-Path $squirrelPath) {
        Write-Host 'Removing SquirrelTemp folder...'
        Remove-Item -Path $squirrelPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host 'SquirrelTemp removed.'
    } else {
        Write-Host 'SquirrelTemp folder not found.'
    }

    # Stop Discord if running
    if ($wasRunning) {
        Stop-Process -Name Discord -ErrorAction SilentlyContinue -Force
        Write-Host 'Stopped Discord process.'
    }

    # Bulk remove cache directories
    $cachePaths = @(
        "$env:APPDATA\Discord\Cache",
        "$env:APPDATA\Discord\Code Cache",
        "$env:APPDATA\Discord\GPUCache"
    )
    Write-Host 'Removing cache directories...'
    Remove-Item -Path $cachePaths -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Cache directories removed.'

    # Remove specified modules
    $modulesDir = Join-Path $basePath 'modules'
    $moduleNames = @('cloudsync','dispatch','erlpack','game_utils','krisp','overlay2','rpc','media','modules','spellcheck')
    Write-Host 'Removing specified discord_ modules...'
    foreach ($mod in $moduleNames) {
        $pattern = "discord_$mod-*"
        Get-ChildItem -Path $modulesDir -Directory -Filter $pattern -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed modules matching: $pattern"
    }

    # Prune locales, keep en-US and ru
    $localesDir = Join-Path $basePath 'locales'
    Write-Host 'Pruning locales...'
    if (Test-Path $localesDir) {
        Get-ChildItem -Path $localesDir -Filter '*.pak' |
            Where-Object { $_.BaseName -notin 'en-US','ru' } |
            Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host 'Unwanted locales removed.'
    } else {
        Write-Host 'Locales directory not found.'
    }

    # Apply DPI override in registry
    $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    $valueName = Join-Path $basePath 'Discord.exe'
    New-ItemProperty -Path $regPath -Name $valueName -Value 'HIGHDPIAWARE' -PropertyType String -Force | Out-Null
    Write-Host 'DPI override set in registry.'

    # Restart Discord if it was running, detached
    if ($wasRunning) {
        Write-Host 'Restarting Discord (detached)...'
        $exePath = Join-Path $basePath 'Discord.exe'
        Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','start','""',$exePath -WindowStyle Hidden -ErrorAction SilentlyContinue
    }

    Write-Host '=== Debloat completed ===' -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
finally {
    Write-Host "`nPress Enter to exit..." -NoNewline
    Read-Host | Out-Null
}
