$ErrorActionPreference = 'Stop'
$envFile = Join-Path $PSScriptRoot '.env'
$template = Join-Path $PSScriptRoot '.env.example'

if (-not (Test-Path $envFile)) {
    Copy-Item $template $envFile
    Write-Host 'Created Backend/.env from .env.example.'
    Write-Host 'Add your server-only API credentials to Backend/.env, then run this script again.'
    exit 1
}

foreach ($rawLine in Get-Content $envFile) {
    $line = $rawLine.Trim()
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
    $equalsAt = $line.IndexOf('=')
    if ($equalsAt -lt 1) { continue }
    $name = $line.Substring(0, $equalsAt).Trim()
    $value = $line.Substring($equalsAt + 1).Trim()
    if ($value.Length -ge 2) {
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
    }
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
}

Push-Location $PSScriptRoot
try {
    dart run server.dart
}
finally {
    Pop-Location
}
