<#
.SYNOPSIS
    Optimized Discord Debloat Script: removes cache, modules, language packs, old versions, logs, sets DPI override, and restarts Discord.
.DESCRIPTION
    - Requires administrator privileges
    - Cleans up old Discord app-* folders, keeping only the latest
    - Removes all *.log files in %LOCALAPPDATA%\Discord
    - Removes specified modules, cache, unwanted locales, and the SquirrelTemp folder
    - Keeps only en-US and ru language packs
    - Applies DPI override in registry
    - Restarts Discord if it was running (detached from PowerShell)
.USAGE:
    Run in PowerShell with administrator privileges:
      PowerShell -ExecutionPolicy Bypass -File .\Debloat-Discord.ps1
#>

# Stop on any error
$ErrorActionPreference = 'Stop'

try {
    # Check for administrator privileges
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        throw 'This script must be run as Administrator.'
    }
    Write-Host '=== Starting Debloat Process ===' -ForegroundColor Cyan

    # Define paths
    $installRoot = "$env:LOCALAPPDATA\Discord"
    $appDataPath = "$env:APPDATA\Discord"
    
    # Check if Discord is running
    $wasRunning = $null -ne (Get-Process -Name Discord -ErrorAction SilentlyContinue)
    if ($wasRunning) {
        Write-Host 'Stopping Discord...' -ForegroundColor Yellow
        Stop-Process -Name Discord -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1 # Give the process time to terminate
    }

    # Find and remove outdated Discord versions
    $allApps = @(Get-ChildItem -Path $installRoot -Directory -Filter 'app-*' | Sort-Object Name -Descending)
    if ($allApps.Count -lt 1) {
        throw 'No Discord app-* folders found.'
    }
    
    # Keep only the latest version
    $latest = $allApps[0]
    $basePath = $latest.FullName
    Write-Host "Using latest version: $($latest.Name)" -ForegroundColor Green
    
    # Parallel removal of outdated versions
    if ($allApps.Count -gt 1) {
        Write-Host "Removing $(($allApps.Count - 1)) outdated versions..." -ForegroundColor Yellow
        $allApps | Select-Object -Skip 1 | ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Simultaneous removal of all unnecessary elements
    Write-Host 'Cleaning cache, logs, and temporary files...' -ForegroundColor Yellow
    
    # Create a list of all paths to remove
    $pathsToRemove = @(
        # Logs
        "$installRoot\*.log"
        # Cache
        "$appDataPath\Cache"
        "$appDataPath\Code Cache"
        "$appDataPath\GPUCache"
        # SquirrelTemp
        "$installRoot\packages\SquirrelTemp"
    )
    
    # Remove all paths in parallel
    $pathsToRemove | ForEach-Object {
        if (Test-Path $_) {
            Remove-Item -Path $_ -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Remove modules
    $modulesDir = "$basePath\modules"
    if (Test-Path $modulesDir) {
        Write-Host 'Removing unnecessary modules...' -ForegroundColor Yellow
        $modulePatterns = @('discord_cloudsync-*', 'discord_dispatch-*', 'discord_erlpack-*', 
                           'discord_game_utils-*', 'discord_krisp-*', 'discord_overlay2-*', 
                           'discord_rpc-*', 'discord_media-*', 'discord_modules-*', 'discord_spellcheck-*')
        
        # Get all module directories to remove
        $modulesToRemove = $modulePatterns | ForEach-Object {
            Get-ChildItem -Path $modulesDir -Directory -Filter $_ -ErrorAction SilentlyContinue
        }
        
        # Remove found modules
        $modulesToRemove | ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Clean locales (keep only en-US and ru)
    $localesDir = "$basePath\locales"
    if (Test-Path $localesDir) {
        Write-Host 'Removing unnecessary language packs...' -ForegroundColor Yellow
        Get-ChildItem -Path $localesDir -Filter '*.pak' | 
            Where-Object { $_.BaseName -notin @('en-US', 'ru') } | 
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    # Set DPI in registry
    Write-Host 'Configuring DPI settings...' -ForegroundColor Yellow
    $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    $discordExePath = "$basePath\Discord.exe"
    Set-ItemProperty -Path $regPath -Name $discordExePath -Value 'HIGHDPIAWARE' -Type String -Force

    # Restart Discord if it was running (properly detached from PowerShell)
    if ($wasRunning) {
        Write-Host 'Restarting Discord (detached)...' -ForegroundColor Green
        # Use Start-Process with cmd.exe to fully detach Discord from PowerShell
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c start """" ""$discordExePath""" -WindowStyle Hidden
    }

    Write-Host '=== Debloat process completed successfully! ===' -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
finally {
    Write-Host "`nPress Enter to exit..." -NoNewline
    Read-Host | Out-Null
}