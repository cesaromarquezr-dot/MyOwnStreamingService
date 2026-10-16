$ErrorActionPreference = 'Stop'

# Run this script from the MyOwnStreamingService project root after extracting the patch.
$projectRoot = $PSScriptRoot
$serverPath = Join-Path $projectRoot 'Backend\server.dart'
if (-not (Test-Path -LiteralPath $serverPath)) {
    $serverPath = Join-Path $projectRoot 'backend\server.dart'
}
if (-not (Test-Path -LiteralPath $serverPath)) {
    throw "Could not find Backend\server.dart. Extract this patch at the MyOwnStreamingService project root."
}

$source = Get-Content -LiteralPath $serverPath -Raw
$original = $source

# Remove the stale import, constructor, constructor-list argument, and parameter.
$source = [regex]::Replace($source, "(?m)^[ \t]*import\s+'routes/radio_routes\.dart';[ \t]*\r?\n", '')
$source = [regex]::Replace($source, "(?ms)^[ \t]*final\s+radioRoutes\s*=\s*RadioRoutes\([ \t]*\r?\n[ \t]*authentication:\s*authentication,[ \t]*\r?\n[ \t]*\);[ \t]*\r?\n(?:[ \t]*\r?\n)?", '')
$source = [regex]::Replace($source, "(?m)^[ \t]*radioRoutes,[ \t]*\r?\n", '')
$source = [regex]::Replace($source, "(?m)^[ \t]*RadioRoutes\s+radioRoutes,[ \t]*\r?\n", '')

# Remove the radio station endpoint block (the app no longer exposes radio streaming).
$radioBlockPattern = "(?ms)^[ \t]*//[- ]+\r?\n[ \t]*//\s*RADIO\s*\r?\n[ \t]*//[- ]+\r?\n(?:[ \t]*\r?\n)*[ \t]*if\s*\(path\s*==\s*'/api/v1/radio/stations'\)\s*\{.*?^[ \t]*\}[ \t]*\r?\n"
$source = [regex]::Replace($source, $radioBlockPattern, '')

if ($source -eq $original) {
    if ($source -match 'RadioRoutes|radio_routes\.dart|radioRoutes|/api/v1/radio/stations') {
        throw 'Radio references were detected, but the expected code blocks did not match. No file was changed.'
    }
    Write-Host 'No obsolete radio backend references found; no changes needed.' -ForegroundColor Green
    exit 0
}

if ($source -match 'RadioRoutes|radio_routes\.dart|radioRoutes|/api/v1/radio/stations') {
    throw 'Some radio-specific references remain after cleanup. No file was changed.'
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupPath = "$serverPath.before_radio_backend_cleanup_$stamp.bak"
Copy-Item -LiteralPath $serverPath -Destination $backupPath
Set-Content -LiteralPath $serverPath -Value $source -Encoding UTF8 -NoNewline

# Verify the saved file; restore the backup if verification fails.
$saved = Get-Content -LiteralPath $serverPath -Raw
if ($saved -match 'RadioRoutes|radio_routes\.dart|radioRoutes|/api/v1/radio/stations') {
    Copy-Item -LiteralPath $backupPath -Destination $serverPath -Force
    throw "Verification failed; original server.dart restored from $backupPath"
}

Write-Host 'Removed stale radio import, registration, parameter, and endpoint handler.' -ForegroundColor Green
Write-Host "Backup saved to: $backupPath"
Write-Host 'Next run: flutter analyze'
