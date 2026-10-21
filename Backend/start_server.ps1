$ErrorActionPreference = "Stop"

$url = [Environment]::GetEnvironmentVariable("SUPABASE_URL", "User")
$key = [Environment]::GetEnvironmentVariable("SUPABASE_SERVICE_ROLE_KEY", "User")

if ([string]::IsNullOrWhiteSpace($url)) {
    throw "SUPABASE_URL is not configured."
}

if ([string]::IsNullOrWhiteSpace($key)) {
    throw "SUPABASE_SERVICE_ROLE_KEY is not configured."
}

$env:SUPABASE_URL = $url
$env:SUPABASE_SERVICE_ROLE_KEY = $key
$publishableKey = [Environment]::GetEnvironmentVariable("SUPABASE_PUBLISHABLE_KEY", "User")
if ([string]::IsNullOrWhiteSpace($publishableKey)) {
    $publishableKey = [Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY", "User")
}
if (-not [string]::IsNullOrWhiteSpace($publishableKey)) {
    $env:SUPABASE_PUBLISHABLE_KEY = $publishableKey
}
# Never inherit the local seeded server catalog into a persistent deployment.
$env:PLATFORM_SERVER_MOCK = "false"
if ([string]::IsNullOrWhiteSpace($env:TLS_CERTIFICATE_PATH)) {
    $env:TLS_CERTIFICATE_PATH = Join-Path $PSScriptRoot "certs\127.0.0.1+2.pem"
}
if ([string]::IsNullOrWhiteSpace($env:TLS_PRIVATE_KEY_PATH)) {
    $env:TLS_PRIVATE_KEY_PATH = Join-Path $PSScriptRoot "certs\127.0.0.1+2-key.pem"
}

Push-Location $PSScriptRoot
try {
    & dart run server.dart
}
finally {
    Pop-Location
}
