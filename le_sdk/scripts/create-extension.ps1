<#
.SYNOPSIS
    Creates a new Lattice Edge Extension from the template.
.DESCRIPTION
    Scaffolds a new extension under my-extensions/ using the template in templates/lattice_edge_extension/.
.PARAMETER ExtensionId
    snake_case identifier (e.g. my_extension)
.PARAMETER Name
    Human-readable name (default: derived from ID)
.PARAMETER Description
    One-line description (default: "A Lattice Edge extension")
.PARAMETER OutputDir
    Target directory for the new extension (default: my-extensions/)
.EXAMPLE
    .\scripts\create-extension.ps1 my_extension
.EXAMPLE
    .\scripts\create-extension.ps1 my_extension "My Extension" "Does cool things"
.EXAMPLE
    .\scripts\create-extension.ps1 my_extension -OutputDir C:\projects\extensions
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ExtensionId,

    [Parameter(Position=1)]
    [string]$Name,

    [Parameter(Position=2)]
    [string]$Description = "A Lattice Edge extension",

    [Parameter(Position=3)]
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

# Validate extension_id is a valid Dart package name (lowercase, underscores, no leading digit)
if ($ExtensionId -notmatch '^[a-z][a-z0-9_]*$') {
    Write-Warning "'$ExtensionId' is not a valid Dart package name."
    Write-Warning "  Must be lowercase_with_underscores, start with a letter, and use only [a-z0-9_]."
    Write-Warning "  See https://dart.dev/tools/pub/pubspec#name"
    $answer = Read-Host "Continue anyway? [y/N]"
    if ($answer -ne 'y' -and $answer -ne 'Y') {
        exit 1
    }
}

# Derive Name from ID if not provided (snake_case -> Title Case)
if (-not $Name) {
    $Name = ($ExtensionId -split '_' | ForEach-Object {
        $_.Substring(0,1).ToUpper() + $_.Substring(1)
    }) -join ' '
}

# Derive PascalCase class name from ID
$Class = ($ExtensionId -split '_' | ForEach-Object {
    $_.Substring(0,1).ToUpper() + $_.Substring(1)
}) -join ''

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplateDir = Join-Path $ScriptDir "..\templates\lattice_edge_extension"
if (-not $OutputDir) {
    $OutputDir = Join-Path $ScriptDir "..\my-extensions"
}
$TargetDir = Join-Path $OutputDir $ExtensionId

# Resolve to absolute paths
$TemplateDir = (Resolve-Path $TemplateDir).Path
$TargetDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetDir)

if (Test-Path $TargetDir) {
    Write-Error "Error: $TargetDir already exists"
    exit 1
}

Write-Host "Creating extension: $Name ($ExtensionId)"
New-Item -ItemType Directory -Path "$TargetDir\lib" -Force | Out-Null
New-Item -ItemType Directory -Path "$TargetDir\assets" -Force | Out-Null

# Compute relative path from TargetDir to the SDK packages directory
$SdkAbs = (Resolve-Path (Join-Path $ScriptDir "..\packages\le_sdk")).Path
# Ensure target dir exists so we can resolve it
New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
$TargetAbs = (Resolve-Path $TargetDir).Path

# Compute relative path (compatible with PowerShell 5.1+)
function Get-RelPath($from, $to) {
    $fromUri = New-Object System.Uri("$from\")
    $toUri = New-Object System.Uri($to)
    $rel = $fromUri.MakeRelativeUri($toUri).ToString()
    return [Uri]::UnescapeDataString($rel)
}
# MakeRelativeUri already produces forward slashes
$SdkPath = Get-RelPath $TargetAbs $SdkAbs

# Copy and substitute templates
Get-ChildItem -Path $TemplateDir -Recurse -Filter "*.template" | ForEach-Object {
    $relativePath = $_.FullName.Substring($TemplateDir.Length + 1)
    $destRelative = $relativePath -replace '\.template$', '' -replace '__ID__', $ExtensionId
    $destPath = Join-Path $TargetDir $destRelative

    $destDir = Split-Path -Parent $destPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $content = Get-Content -Path $_.FullName -Raw
    $content = $content -replace '__ID__', $ExtensionId
    $content = $content -replace '__NAME__', $Name
    $content = $content -replace '__DESCRIPTION__', $Description
    $content = $content -replace '__CLASS__', $Class
    $content = $content -replace '__SDK_PATH__', $SdkPath
    Set-Content -Path $destPath -Value $content -NoNewline
}

# Create placeholder icon
$sampleIcon = Join-Path $ScriptDir "..\samples\field_report\assets\logo.png"
if (Test-Path $sampleIcon) {
    Copy-Item -Path $sampleIcon -Destination "$TargetDir\assets\logo.png"
} else {
    New-Item -ItemType File -Path "$TargetDir\assets\logo.png" -Force | Out-Null
}

# Copy bundled fonts (Roboto for offline web support)
$templateFonts = Join-Path $TemplateDir "fonts"
if (Test-Path $templateFonts) {
    New-Item -ItemType Directory -Path "$TargetDir\fonts" -Force | Out-Null
    Copy-Item -Path "$templateFonts\*" -Destination "$TargetDir\fonts\" -Force
}

Write-Host ""
Write-Host "Extension created at: $TargetDir"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  cd $TargetDir"
Write-Host "  flutter pub get"
Write-Host "  flutter run -d <device>     # standalone preview"
Write-Host "  flutter build web           # web build for host testing"
Write-Host ""
Write-Host "See docs\developer-guide.md for full instructions."
