# Self-hosting, remote access, VPN behavior, and security

This project is designed as a personal-media platform: the account library is made from media the account is authorized to store and stream. The application does **not** implement Netflix/Disney-style country licensing or catalog geoblocking.

## Remote-access architecture

Recommended production path:

`Internet -> Cloudflare DNS/proxy -> home firewall -> NGINX Proxy Manager -> Flutter web/backend service`

Only the reverse proxy should normally be exposed on HTTPS (TCP 443). Internal services should remain on private network addresses and should not each receive their own public port.

### NGINX Proxy Manager

NGINX Proxy Manager provides hostname-based reverse-proxy routing. A hostname such as `stream.example.com` can be mapped to the internal streaming service without exposing the application's internal port directly.

### Cloudflare

Cloudflare can provide DNS, proxying, TLS, WAF/rate-limiting controls, and an additional public edge layer. The origin firewall should be configured so that public HTTPS traffic is accepted only through the intended Cloudflare path when that operating model is used.

Do not treat Cloudflare as the only security boundary. The home firewall, reverse proxy, application authentication, operating system, containers, and database permissions all remain security boundaries.

### Dynamic public IP / DDNS

If an ISP changes the home's public IPv4 address, the DNS record must be updated. A Cloudflare DDNS client can periodically discover the current public address and update the Cloudflare DNS record automatically.

The DDNS process should use a narrowly scoped Cloudflare API token that can update only the required DNS zone/record. Do not place a global Cloudflare API key in source code.

### VPN alternative

A self-hosted VPN such as WireGuard can be used when the owner wants private remote access instead of publishing the application publicly. A VPN is particularly useful for administration, NAS/SMB access, and services that do not need to be public.

## VPNs and media availability

A VPN should not change the media catalog in this project. A user can travel from one country to another, use a VPN, or change networks and still access media that belongs to their account, subject to normal account authentication and server availability.

The `discRegion` metadata stored for physical media describes the source disc/release and is **not** a licensing geofence. It should not be used to hide an owned movie or show from the account based on the user's IP country.

A changing VPN/network can legitimately look like a new login environment. The backend may therefore flag a new IP/browser/device fingerprint for security notifications. That security signal must not be used as a content-availability rule.

## Password and account protection

The backend stores password hashes rather than plaintext passwords and uses Argon2id through `password_guard`. Password reset answers are also hashed. Session credentials are treated separately from password credentials.

Production deployment should additionally use:

- HTTPS everywhere outside the trusted local network.
- MFA/passkeys for account owners when available.
- Login rate limiting at both the reverse-proxy edge and application layer.
- Per-account and per-IP failed-login throttling without revealing whether an email exists.
- Short-lived session tokens with rotation/revocation support.
- Secure, HttpOnly, SameSite cookies for web sessions where cookies are used.
- Least-privilege database/RLS policies.
- No plaintext payment card/CVV storage.
- Automatic operating-system, container, router, reverse-proxy, and firmware updates as part of a maintenance process.
- Network segmentation/VLANs so internet-facing services cannot freely reach trusted LAN devices.
- Backups that are encrypted and tested for restoration.
- IDS/IPS at the firewall where supported.

### Password attack defenses

- **Rainbow tables:** Argon2id uses a unique salt as part of the password-hashing process, making precomputed rainbow tables impractical for the stored hashes.
- **Dumpster diving:** Do not store passwords in paper notes, exported logs, backups, source files, or removable media. Sanitize discarded disks and computers.
- **Shoulder surfing:** Use password masking, passkeys/MFA, device lock, and privacy-aware login screens.
- **Hardware/software keyloggers:** Keep server/client operating systems patched and restrict physical and administrative access.
- **Brute force/dictionary attacks:** Use long unique passwords plus login throttling and MFA/passkeys.
- **Adversary-in-the-middle/on-path attacks:** Use HTTPS with valid certificates, secure DNS practices, and avoid accepting invalid certificates.
- **SQL injection:** Use parameterized database APIs/queries and never concatenate untrusted input into SQL.
- **Credential stuffing:** Never reuse the streaming-service password elsewhere; use MFA/passkeys and breached-password screening where practical.
- **Phishing:** Users should verify the hostname before entering credentials and avoid authentication links from unexpected messages.

## Reverse proxy vs. service redirection

A reverse proxy is different from a normal HTTP redirect. A reverse proxy receives the client's request and forwards it to an internal service while keeping the public hostname stable. A 301/302 redirect instead tells the client to make another request to a different URL.

For this architecture, use reverse-proxy routing for application services rather than exposing every internal service with a separate public port.
