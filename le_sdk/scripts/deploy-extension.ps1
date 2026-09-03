<#
.SYNOPSIS
    Deploy Lattice Edge Extension.
.DESCRIPTION
    Default: serves the extension from the dev machine with hot reload and
    auto-registers the URL on a connected Android device/emulator.
.PARAMETER ExtensionDir
    Path to the extension directory (default: current directory)
.PARAMETER DeployOnDevice
    Build and push files to device instead of serving
.PARAMETER Register
    Auto-register in SharedPreferences (only with -DeployOnDevice; implied in serve mode)
.PARAMETER NoBuild
    Skip flutter build web (use existing build output)
.PARAMETER Wasm
    Use wasm dev server (fast load, recompile on restart; serve mode only)
.PARAMETER Port
    Port for the web dev server (default: 8080, serve mode only)
.PARAMETER DeviceSerial
    Optional adb device serial for multi-device setups
.EXAMPLE
    .\deploy-extension.ps1 ..\samples\field_report
.EXAMPLE
    .\deploy-extension.ps1 -Port 9090 ..\samples\field_report
.EXAMPLE
    .\deploy-extension.ps1 -DeployOnDevice -Register ..\samples\field_report
.EXAMPLE
    .\deploy-extension.ps1 -DeployOnDevice -NoBuild ..\samples\field_report
#>
param(
    [Parameter(Position=0)]
    [string]$ExtensionDir = (Get-Location).Path,

    [Parameter()]
    [switch]$DeployOnDevice,

    [Parameter()]
    [switch]$Register,

    [Parameter()]
    [switch]$NoBuild,

    [Parameter()]
    [switch]$Wasm,

    [Parameter()]
    [int]$Port = 8080,

    [Parameter()]
    [string]$DeviceSerial
)

$ErrorActionPreference = "Stop"

################################################################################
# Helpers
################################################################################

function Print-Success($msg) { Write-Host "  $msg" -ForegroundColor Green }
function Print-Error($msg)   { Write-Host "  $msg" -ForegroundColor Red }
function Print-Info($msg)    { Write-Host "  $msg" -ForegroundColor Cyan }
function Print-Warning($msg) { Write-Host "  $msg" -ForegroundColor Yellow }

function Print-Header($msg) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor White
    Write-Host "  $msg" -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor White
    Write-Host ""
}

################################################################################
# Pubspec parsing helpers
################################################################################

function Get-PubspecField($Key) {
    $m = Select-String -Path $PubspecPath -Pattern "^${Key}:\s*(.+)$" | Select-Object -First 1
    if ($m) { return $m.Matches.Groups[1].Value.Trim().Trim("'`"") }
    return $null
}

function Get-PubspecSectionField($Section, $Key) {
    $lines = Get-Content $PubspecPath
    $inSection = $false
    foreach ($line in $lines) {
        if ($line -match "^${Section}:\s*$") { $inSection = $true; continue }
        if ($inSection) {
            if ($line -match '^\S') { break }
            if ($line -match "^\s+${Key}:\s*(.+)$") {
                return $Matches[1].Trim().Trim("'`"")
            }
        }
    }
    return $null
}

################################################################################
# Register extension in SharedPreferences
################################################################################

function Register-Extension($Url) {
    $PkgName = $Id
    $Description = (Get-PubspecField 'description') -replace '\s+', ' ' -replace '>\s*$', ''
    $Version = Get-PubspecField 'version'

    # Try lattice_edge_extension first, then lattice_plugin
    $Section = 'lattice_edge_extension'
    $Icon = Get-PubspecSectionField $Section 'icon'
    if (-not $Icon) {
        $Section = 'lattice_plugin'
        $Icon = Get-PubspecSectionField $Section 'icon'
    }

    $DisplayMode = Get-PubspecSectionField $Section 'display_mode'
    if (-not $DisplayMode) { $DisplayMode = 'panel' }
    $SectDesc = Get-PubspecSectionField $Section 'description'
    if ($SectDesc) { $Description = $SectDesc }

    # Build IDs matching host's _registerFromPubspec format
    $ExtId = 'web_' + ($PkgName.ToLower() -replace '[^a-z0-9]', '_')
    $DisplayName = ($PkgName -split '_' | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1) }) -join ' '
    if ($Version) { $DisplayName = "$DisplayName (v$Version)" }

    # Build manifest object
    $Manifest = [ordered]@{
        id          = $ExtId
        name        = $DisplayName
        type        = 'web'
        url         = $Url
        displayMode = $DisplayMode
    }
    if ($Description) { $Manifest['description'] = $Description }
    if ($Icon) { $Manifest['icon'] = $Icon }
    # Include iconImagePath only for on-device deployments (file:// URLs)
    if ($Url -like 'file://*' -and (Test-Path (Join-Path $ExtensionDir "assets\logo.png"))) {
        $DeviceExtPath = "/sdcard/LatticeEdge/extensions/$PkgName"
        $Manifest['iconImagePath'] = "$DeviceExtPath/assets/logo.png"
    }

    $ManifestJson = $Manifest | ConvertTo-Json -Compress
    Print-Info "Manifest: $ManifestJson"

    # --- Read current SharedPreferences ---
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    $PrefsTmp = [System.IO.Path]::GetTempFileName()
    & @AdbCmd shell "run-as $AppPackage cat $PrefsFile" 2>$null | Set-Content -Path $PrefsTmp -Encoding UTF8

    if (-not (Test-Path $PrefsTmp) -or (Get-Item $PrefsTmp).Length -eq 0) {
        Print-Error "Could not read SharedPreferences. Is $AppPackage installed and debuggable?"
        Remove-Item -Force $PrefsTmp -ErrorAction SilentlyContinue
        exit 1
    }

    # --- Update SharedPreferences XML ---
    [xml]$PrefsXml = Get-Content -Path $PrefsTmp -Raw

    $WebPluginsNode = $PrefsXml.map.string | Where-Object { $_.name -eq 'flutter.web_plugins' }

    $Existing = @()
    if ($WebPluginsNode) {
        try { $Existing = @(($WebPluginsNode.'#text' | ConvertFrom-Json)) } catch { $Existing = @() }
        # Remove any existing entry with the same id (upsert)
        $Existing = @($Existing | Where-Object { $_.id -ne $ExtId })
        $Existing += $Manifest
        $WebPluginsNode.'#text' = [string](ConvertTo-Json $Existing -Compress)
    } else {
        $NewNode = $PrefsXml.CreateElement('string')
        $NewNode.SetAttribute('name', 'flutter.web_plugins')
        $NewNode.InnerText = [string](ConvertTo-Json @($Manifest) -Compress)
        $PrefsXml.map.AppendChild($NewNode) | Out-Null
    }

    $PrefsOut = [System.IO.Path]::GetTempFileName()
    $PrefsXml.Save($PrefsOut)

    # Push updated prefs back to device
    Get-Content -Path $PrefsOut -Raw | & @AdbCmd shell "run-as $AppPackage sh -c 'cat > $PrefsFile'"

    Remove-Item -Force $PrefsTmp, $PrefsOut -ErrorAction SilentlyContinue

    $ErrorActionPreference = $prevEAP

    Print-Success "Extension registered"

    # Restart the app
    Print-Info "Restarting $AppPackage..."
    & @AdbCmd shell "am force-stop $AppPackage" 2>$null
    Start-Sleep -Seconds 1
    & @AdbCmd shell "monkey -p $AppPackage -c android.intent.category.LAUNCHER 1" 2>$null
    Print-Success "App restarted"
}

################################################################################
# Resolve extension directory
################################################################################

$ExtensionDir = (Resolve-Path $ExtensionDir -ErrorAction Stop).Path

Print-Header "Deploy Lattice Edge Extension"

################################################################################
# Validate extension directory
################################################################################

$PubspecPath = Join-Path $ExtensionDir "pubspec.yaml"
if (-not (Test-Path $PubspecPath)) {
    Print-Error "No pubspec.yaml found in $ExtensionDir"
    Write-Host "  Make sure you are in an extension directory or pass the path as an argument."
    exit 1
}

# Extract extension ID from pubspec name field
$Id = (Select-String -Path $PubspecPath -Pattern '^name:\s*(.+)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
if (-not $Id) {
    Print-Error "Could not read 'name:' from pubspec.yaml"
    exit 1
}

Print-Info "Extension: $Id"
Print-Info "Directory: $ExtensionDir"

# Check for manifest section (warn only)
$PubspecContent = Get-Content $PubspecPath -Raw
if ($PubspecContent -notmatch 'lattice_edge_extension:' -and $PubspecContent -notmatch 'lattice_plugin:') {
    Print-Warning "No 'lattice_edge_extension:' or 'lattice_plugin:' section in pubspec.yaml"
    Print-Warning "The host app will use defaults (entry: web/index.html, display_mode: panel)"
}

################################################################################
# Locate adb
################################################################################

$Adb = Get-Command adb -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $Adb) {
    $AndroidHome = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
    $Adb = Join-Path $AndroidHome "platform-tools\adb.exe"
}

if (-not (Test-Path $Adb)) {
    Print-Error "adb not found. Install Android SDK platform-tools or set ANDROID_HOME."
    exit 1
}

Print-Success "Found adb: $Adb"

# Build adb command with optional serial
$AdbCmd = @($Adb)
if ($DeviceSerial) { $AdbCmd += @("-s", $DeviceSerial) }

################################################################################
# Verify device connected
################################################################################

$DeviceLines = & $Adb devices | Where-Object { $_ -match '\tdevice$' }
$DeviceCount = ($DeviceLines | Measure-Object).Count

if ($DeviceCount -eq 0) {
    Print-Error "No Android device/emulator connected."
    Write-Host "  Start an emulator or connect a device, then retry."
    exit 1
}

if ($DeviceCount -gt 1 -and -not $DeviceSerial) {
    $FirstDevice = ($DeviceLines | Select-Object -First 1) -replace '\s.*',''
    Print-Warning "Multiple devices detected. Using: $FirstDevice"
    Print-Warning "Use -DeviceSerial to target a specific device."
}

Print-Success "Device connected"

################################################################################
# Detect emulator vs physical device
################################################################################

$AppPackage = "com.lattice.webview"
$PrefsFile = "shared_prefs/FlutterSharedPreferences.xml"

$IsEmulator = $false
$Qemu = (& @AdbCmd shell "getprop ro.kernel.qemu" 2>$null) -replace '\r',''
if ($Qemu -eq "1") {
    $IsEmulator = $true
}

function Resolve-HostIp {
    if ($IsEmulator) {
        # Use adb reverse so the emulator accesses the server via localhost,
        # bypassing the slow virtual network (10.0.2.2 truncates large files)
        & @AdbCmd reverse "tcp:$Port" "tcp:$Port" 2>$null
        Print-Info "Set up adb reverse tcp:${Port} for emulator"
        return "127.0.0.1"
    }
    # Physical device - find LAN IP via ipconfig (Windows)
    $ip = $null
    $ipconfigOutput = ipconfig 2>$null
    if ($ipconfigOutput) {
        $match = $ipconfigOutput | Select-String 'IPv4' | Select-Object -First 1
        if ($match) {
            $ip = ($match -replace '.*:\s*','').Trim()
        }
    }
    if (-not $ip) {
        Print-Error "Could not detect host IP address."
        Write-Host "  Set `$env:HOST_IP environment variable manually."
        exit 1
    }
    return $ip
}

################################################################################
# Mode dispatch
################################################################################

if (-not $DeployOnDevice) {
    ############################################################################
    # Serve mode (default)
    ############################################################################

    # Check if port is already in use
    $PortCheck = netstat -ano 2>$null | Select-String ":$Port\s.*LISTENING"
    if ($PortCheck) {
        $PortPid = ($PortCheck -split '\s+' | Select-Object -Last 1).Trim()
        Print-Warning "Port $Port is already in use (PID $PortPid)"
        $answer = Read-Host "  Kill the process? [y/N]"
        if ($answer -eq 'y' -or $answer -eq 'Y') {
            Stop-Process -Id $PortPid -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            Print-Success "Process killed"
        } else {
            Print-Error "Port $Port is in use. Use -Port to specify a different port."
            exit 1
        }
    }

    $HostIp = if ($env:HOST_IP) { $env:HOST_IP } else { Resolve-HostIp }
    $ServeUrl = "http://${HostIp}:${Port}"

    Print-Header "Serve Mode"
    Print-Info "URL: $ServeUrl"
    if ($IsEmulator) {
        Print-Info "Emulator detected - using 10.0.2.2 (host loopback alias)"
    } else {
        Print-Info "Physical device - using host LAN IP: $HostIp"
    }

    # Check if extension is already registered with this URL (skip restart if so)
    $AlreadyRegistered = $false
    $prevEAP2 = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $PrefsCheck = & @AdbCmd shell "run-as $AppPackage cat $PrefsFile" 2>$null
    $ErrorActionPreference = $prevEAP2
    if ($PrefsCheck -and ($PrefsCheck -join '' | Select-String -SimpleMatch "$ServeUrl" -Quiet)) {
        $AlreadyRegistered = $true
    }

    if ($AlreadyRegistered) {
        Print-Success "Extension already registered at $ServeUrl (skipping app restart)"
    } else {
        Print-Header "Registering Extension"
        Register-Extension $ServeUrl
    }

    if ($Wasm) {
        Print-Header "Starting Wasm Dev Server"
        Print-Info "Extension: $Id"
        Print-Info "Serving at: $ServeUrl"
        Print-Info "Recompiles on restart (~1s). Press Ctrl+C to stop, then re-run to pick up changes."
        Write-Host ""

        $OriginalDir = Get-Location
        Set-Location $ExtensionDir
        flutter run -d web-server --web-port $Port --web-hostname 0.0.0.0 --wasm
        Set-Location $OriginalDir
        return
    }

    # Build release web
    if ($NoBuild) {
        Print-Info "Skipping build (-NoBuild)"
    } else {
        Print-Header "Building Web (release)"
        $OriginalDir = Get-Location
        Set-Location $ExtensionDir
        flutter build web --no-web-resources-cdn
        if ($LASTEXITCODE -ne 0) {
            Set-Location $OriginalDir
            throw "flutter build web failed"
        }
        Set-Location $OriginalDir
        Print-Success "Web build complete"
    }

    $IndexPath = Join-Path $ExtensionDir "build\web\index.html"
    if (-not (Test-Path $IndexPath)) {
        Print-Error "build/web/index.html not found. Run without -NoBuild first."
        exit 1
    }

    # Serve the release build
    Print-Header "Starting Web Server"
    Print-Info "Extension: $Id"
    Print-Info "Serving at: $ServeUrl"
    Print-Info "Press Ctrl+C to stop"
    Write-Host ""

    $WebDir = Join-Path $ExtensionDir "build\web"
    python3 -m http.server $Port --directory $WebDir --bind 0.0.0.0

} else {
    ############################################################################
    # Deploy-on-device mode
    ############################################################################

    # Build web
    if ($NoBuild) {
        Print-Info "Skipping build (-NoBuild)"
    } else {
        Print-Header "Building Web"

        # Run flutter build from the extension directory
        $OriginalDir = Get-Location
        Set-Location $ExtensionDir
        flutter build web --no-web-resources-cdn
        if ($LASTEXITCODE -ne 0) {
            Set-Location $OriginalDir
            throw "flutter build web failed"
        }
        Set-Location $OriginalDir

        Print-Success "Web build complete"
    }

    $IndexPath = Join-Path $ExtensionDir "build\web\index.html"
    if (-not (Test-Path $IndexPath)) {
        Print-Error "build/web/index.html not found. Run without -NoBuild first."
        exit 1
    }

    ############################################################################
    # Push to device
    ############################################################################

    Print-Header "Deploying to Device"

    $DevicePath = "/sdcard/LatticeEdge/extensions/$Id"

    Print-Info "Target: $DevicePath"

    # adb writes progress to stderr; temporarily allow stderr
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    & @AdbCmd shell "mkdir -p '$DevicePath/web'" 2>$null

    Print-Info "Pushing pubspec.yaml..."
    & @AdbCmd push "$PubspecPath" "$DevicePath/pubspec.yaml" 2>$null

    Print-Info "Pushing web build..."
    & @AdbCmd push (Join-Path $ExtensionDir "build\web\.") "$DevicePath/web/" 2>$null

    # Push icon if present
    $IconPath = Join-Path $ExtensionDir "assets\logo.png"
    if (Test-Path $IconPath) {
        Print-Info "Pushing icon..."
        & @AdbCmd shell "mkdir -p '$DevicePath/assets'" 2>$null
        & @AdbCmd push $IconPath "$DevicePath/assets/logo.png" 2>$null
    }

    $ErrorActionPreference = $prevEAP

    ############################################################################
    # Verify
    ############################################################################

    $VerifyResult = & @AdbCmd shell "ls '$DevicePath/pubspec.yaml' '$DevicePath/web/index.html'" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Print-Success "Deployment verified"
    } else {
        Print-Error "Verification failed - files may not have been pushed correctly."
        exit 1
    }

    ############################################################################
    # Register (optional)
    ############################################################################

    if ($Register) {
        Print-Header "Registering Extension"

        $Entry = Get-PubspecSectionField 'lattice_edge_extension' 'entry'
        if (-not $Entry) { $Entry = Get-PubspecSectionField 'lattice_plugin' 'entry' }
        if (-not $Entry) { $Entry = 'web/index.html' }

        Register-Extension "file://$DevicePath/$Entry"
    }

    ############################################################################
    # Done
    ############################################################################

    Print-Header "Deployed: $Id"

    Write-Host "  Files pushed to: $DevicePath"

    if ($Register) {
        Write-Host "  Extension registered - it should appear in the extension grid."
    } else {
        Write-Host ""
        Write-Host "  First-time setup (one time only):"
        Write-Host "    1. Open Lattice Edge on the device"
        Write-Host "    2. Tap the Settings gear icon"
        Write-Host '    3. Under "Register Plugin", tap "Browse for Plugin Package"'
        Write-Host "    4. Navigate to: LatticeEdge > extensions > $Id"
        Write-Host "    5. Select the folder - the extension will appear in the grid"
        Write-Host ""
        Write-Host "  Or re-run with -Register to auto-register."
    }
    Write-Host ""
    Write-Host "  For subsequent deploys, just re-run this script."
    Write-Host "  The extension updates automatically on next load."
    Write-Host ""
}
