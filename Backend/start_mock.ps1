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
$env:ALLOWED_ORIGINS = "http://localhost,http://127.0.0.1"
Write-Host "ARM mode: MOCK (Phase 1)" -ForegroundColor Yellow
Write-Host "ARM verification: PASS" -ForegroundColor Yellow
Write-Host ""
Write-Host "Starting backend..." -ForegroundColor Green
Write-Host ""

dart run server.dart

Write-Host ""
Write-Host "Backend process exited with code $LASTEXITCODE." -ForegroundColor Yellow
