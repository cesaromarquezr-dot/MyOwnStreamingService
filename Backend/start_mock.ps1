# FILE: Backend/start_mock.ps1
#
# Purpose:
# Starts the Dart backend in Phase 1 ARM mock mode for local development.
# The environment variables apply only to this PowerShell process.

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Streaming Service Backend - MOCK ARM" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$env:ARM_MOCK = "true"
$env:ARM_MOCK_VERIFY_FAIL = "false"
$env:PAYMENT_MOCK = "true"
$env:ALLOWED_ORIGINS = "http://localhost,http://127.0.0.1"
$certificateConfigured = -not [string]::IsNullOrWhiteSpace($env:TLS_CERTIFICATE_PATH)
$privateKeyConfigured = -not [string]::IsNullOrWhiteSpace($env:TLS_PRIVATE_KEY_PATH)
$customTlsPairExists = $certificateConfigured -and
    $privateKeyConfigured -and
    (Test-Path -LiteralPath $env:TLS_CERTIFICATE_PATH) -and
    (Test-Path -LiteralPath $env:TLS_PRIVATE_KEY_PATH)
if (-not $customTlsPairExists) {
    if ($certificateConfigured -or $privateKeyConfigured) {
        Write-Warning "Configured TLS certificate pair is incomplete or missing; using the bundled mock-development certificate."
    }
    $env:TLS_CERTIFICATE_PATH = Join-Path $PSScriptRoot "certs\127.0.0.1+2.pem"
    $env:TLS_PRIVATE_KEY_PATH = Join-Path $PSScriptRoot "certs\127.0.0.1+2-key.pem"
}
Write-Host "ARM mode: MOCK (Phase 1)" -ForegroundColor Yellow
Write-Host "ARM verification: PASS" -ForegroundColor Yellow
Write-Host "Payment processor: MOCK" -ForegroundColor Yellow
Write-Host ""
Write-Host "Starting backend..." -ForegroundColor Green
Write-Host ""

$backendExitCode = 0
Push-Location $PSScriptRoot
try {
    dart run server.dart
    $backendExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Backend process exited with code $backendExitCode." -ForegroundColor Yellow
