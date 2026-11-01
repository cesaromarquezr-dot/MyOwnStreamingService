[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

try {
    $resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
} catch {
    throw "Project root not found: $ProjectRoot"
}

$pubspecPath = Join-Path $resolvedRoot 'pubspec.yaml'
$targetPath = Join-Path $resolvedRoot 'lib\widgets\hover_preview_card.dart'
$sourcePath = Join-Path $PSScriptRoot 'payload\lib\widgets\hover_preview_card.dart'

if (-not (Test-Path -LiteralPath $pubspecPath -PathType Leaf)) {
    throw "Could not find pubspec.yaml in '$resolvedRoot'. Pass the MyOwnStreamingService project root."
}
if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
    throw "Target file not found: $targetPath"
}
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Patch payload not found: $sourcePath"
}

$sourceText = [System.IO.File]::ReadAllText($sourcePath)
if ($sourceText -notmatch 'previewSettingsPageId' -or
    $sourceText -notmatch 'effectivePreviewPageId') {
    throw 'Patch payload validation failed. No project files were changed.'
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $resolvedRoot ".patch_backups\preview_settings_page_id_fix_$stamp"
$backupFile = Join-Path $backupDir 'lib\widgets\hover_preview_card.dart'
New-Item -ItemType Directory -Path (Split-Path -Parent $backupFile) -Force | Out-Null
Copy-Item -LiteralPath $targetPath -Destination $backupFile -Force

try {
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    $installedText = [System.IO.File]::ReadAllText($targetPath)
    if ($installedText -notmatch 'previewSettingsPageId' -or
        $installedText -notmatch 'effectivePreviewPageId') {
        throw 'Installed file validation failed.'
    }
} catch {
    Copy-Item -LiteralPath $backupFile -Destination $targetPath -Force
    throw "Patch failed; original file restored from '$backupFile'. Details: $($_.Exception.Message)"
}

Write-Host 'Preview settings page ID fix installed.' -ForegroundColor Green
Write-Host "Updated: $targetPath"
Write-Host "Backup:  $backupFile"
Write-Host ''
Write-Host 'Next run: flutter analyze'
