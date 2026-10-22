$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$exclude = '\\(\.git|\.dart_tool|build|node_modules|\.idea|\.vscode|chrome-device|browser-profile|browser_profiles|user-data-dir)\\'
$textExtensions = @('.dart','.sql','.ps1','.psm1','.json','.yaml','.yml','.toml','.xml','.md','.txt','.properties','.env','.example','.pem','.key','.crt')
$patterns = @(
    @{ Name = 'Private key material'; Regex = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----' },
    @{ Name = 'Cloud/service credential assignment'; Regex = '(?im)\b(?:SUPABASE_SERVICE_ROLE_KEY|PROXY_SHARED_SECRET|PAYPAL_CLIENT_SECRET|MERCADO_PAGO_ACCESS_TOKEN)\s*[:=]\s*["'']?(?!\$|<|your[_ -]|changeme|placeholder|example)[A-Za-z0-9_./+=-]{24,}' },
    @{ Name = 'GitHub personal access token'; Regex = '\b(?:ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})\b' },
    @{ Name = 'Live payment secret'; Regex = '\bsk_live_[A-Za-z0-9]{16,}\b' }
)

$findings = @()
Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch $exclude -and
        (($textExtensions -contains $_.Extension.ToLowerInvariant()) -or $_.Name -like '.env*') -and
        $_.Length -le 2MB
    } | ForEach-Object {
        $file = $_
        foreach ($pattern in $patterns) {
            Select-String -LiteralPath $file.FullName -Pattern $pattern.Regex -AllMatches -ErrorAction SilentlyContinue |
                ForEach-Object {
                    $findings += [pscustomobject]@{
                        Rule = $pattern.Name
                        File = $file.FullName.Substring($root.Length + 1)
                        Line = $_.LineNumber
                    }
                }
        }
    }

if ($findings.Count -gt 0) {
    Write-Host 'Potential secret findings (review manually; do not paste secrets into tickets/chat):' -ForegroundColor Red
    $findings | Format-Table -AutoSize
    exit 1
}

Write-Host 'No matching high-confidence secret patterns found in scanned text files.' -ForegroundColor Green
Write-Host 'This scan does not inspect Git history, binary files, or every credential format. Use a dedicated scanner in CI as well.' -ForegroundColor Yellow
