# FILE: Backend/start_mock.ps1
#
# Purpose:
# Starts the Dart backend in Phase 1 ARM mock mode for local development.
#
# This script intentionally sets ARM_MOCK only for the current PowerShell
# process. It does not permanently modify Windows environment variables.
#
# The real ARM service remains the default when ARM_MOCK is not enabled.

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Streaming Service Backend - MOCK ARM" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Enable the deterministic Phase 1 ARM simulator for this backend process.
$env:ARM_MOCK = "true"

# Make sure a previous test-only verification failure setting does not
# accidentally carry into this development session.
$env:ARM_MOCK_VERIFY_FAIL = "false"

Write-Host "ARM mode: MOCK (Phase 1)" -ForegroundColor Yellow
Write-Host "ARM verification: PASS" -ForegroundColor Yellow
Write-Host ""
Write-Host "Starting backend..." -ForegroundColor Green
Write-Host ""

dart run server.dart

Write-Host ""
Write-Host "Backend process exited with code $LASTEXITCODE." -ForegroundColor Yellow