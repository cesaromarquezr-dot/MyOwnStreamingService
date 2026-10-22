# MyOwnStreamingService security hardening

This patch adds application-level guardrails. It does **not** guarantee zero
breaches and does not replace operating-system firewall rules, a correctly
configured reverse proxy/WAF, secret rotation, or a reviewed Supabase policy.

## Changes in this patch

- Fail-closed startup validation when `APP_ENV=production` is explicitly set.
- Production requires a public HTTPS URL, `REQUIRE_TRUSTED_PROXY=true`, a
  32+ character `PROXY_SHARED_SECRET`, narrow valid `TRUSTED_PROXY_CIDRS`, an
  explicit list of exact HTTPS `ALLOWED_ORIGINS`, and disabled mock services.
- Endpoint-specific IP throttles for login, signup/invitation acceptance,
  password recovery, MFA, password changes, session rotation and logout-all,
  layered on the existing global per-IP limiter.
- Hard caps for request bodies, including chunked request streams. The default
  is 25 MiB and can be changed with `MAX_REQUEST_BODY_BYTES` (1 KiB–100 MiB).
  Media bytes should not be uploaded to the API JSON endpoints.
- Route-local wildcard `Access-Control-Allow-Origin: *` headers were removed
  so they no longer overwrite the central origin allowlist. The main request
  dispatcher owns the allow-origin decision.
- A read-only Supabase RLS audit query and a local repository secret scanner.
- Regression tests for rate policy, bounded bodies, and production guardrails.

Rate limits are process-local, per source IP and reset on backend restart. They
are not a distributed/global rate limiter. Keep rate limiting at the reverse
proxy/WAF too, especially if running multiple backend instances.

## Local development

Do not set `APP_ENV=production` in your Windows development terminal. Continue
using the current development launcher/environment and keep local mock mode
out of production. `Backend/start_server.ps1` is intentionally not changed by
this patch, so preserve your local server-catalog mock fix.

## Production configuration checklist

Set these in the backend service environment, not in Flutter and not in source
control. `APP_ENV=production` is recommended explicitly even though a non-loopback
public URL also enables production checks by default:

```text
APP_ENV=production
SERVER_PUBLIC_URL=https://your-real-app-domain.example
REQUIRE_TRUSTED_PROXY=true
PROXY_SHARED_SECRET=<at least 32 random characters, shared with the trusted proxy>
TRUSTED_PROXY_CIDRS=<exact proxy IPs or narrow CIDRs, comma-separated>
ALLOWED_ORIGINS=https://your-real-app-domain.example
BACKEND_TLS_ENABLED=false
```

`BACKEND_TLS_ENABLED=false` is appropriate only if a trusted reverse proxy
terminates public TLS and the internal proxy-to-backend hop is suitably
protected. If Dart terminates TLS directly, keep TLS enabled and still use the
configured proxy guard for the production entry point. Use the real browser app
origin in `ALLOWED_ORIGINS`; do not include URL paths. Wildcards and plain HTTP
origins are rejected in production mode.

Before setting `APP_ENV=production`, configure the actual reverse proxy and
verify it strips any client-supplied `X-Streaming-Proxy-Key` and injects the
secret header itself only when proxying to the backend. Configure
`TRUSTED_PROXY_CIDRS` for the immediate peer addresses only; never use
`0.0.0.0/0` or `::/0`. Generate the proxy secret with a cryptographically secure
random generator and configure it on both sides without printing it in logs.

Production must not set any of these mock flags to true:
`ARM_MOCK`, `PLATFORM_SERVER_MOCK`, `PAYMENT_MOCK`, `FOOD_PAYMENT_MOCK`.

## Network exposure guidance

- Do not port-forward port 8080, database ports, or raw AI/model-server ports
  directly to the internet.
- Expose only the required reverse-proxy entry point (normally 443; port 80
  only when deliberately used for redirect/challenge handling).
- Keep database, storage, management consoles and AI endpoints on a private
  network/VPN. Restrict admin endpoints with application authorization even
  when they are network-private.
- A WAF is an optional extra layer before the reverse proxy. It can block many
  malicious requests but cannot fix broken API authorization, vulnerable code,
  leaked credentials or bad database policies.
- Use `Backend/database/security_audit_readonly.sql` to inventory RLS state and
  policies. Review each result; do not automatically add broad policies because
  policy conditions depend on each table's data model.
- Supabase service-role credentials bypass RLS. Keep them backend-only and
  continue enforcing account/member/profile authorization inside each API path.
- Rotate credentials if a private key, browser profile, token, or environment
  file was ever included in a project archive shared outside your machine.

## Local checks

From `Backend/`:

```powershell
dart test test/security_hardening_test.dart
```

From the project root:

```powershell
.\scripts\security\scan_repository.ps1
flutter analyze
flutter test
```

The secret scanner is a useful local tripwire, not a complete secret scanner;
for Git history and CI, use a dedicated scanner such as Gitleaks and enable host
secret scanning. If a secret was committed, ignoring it later does not remove it
from Git history: revoke/rotate it first, then clean history only when safe.
