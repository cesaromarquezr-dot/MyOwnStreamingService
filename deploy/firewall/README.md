# Firewall

Recommended router policy:

- Internet TCP 443 -> NGINX Proxy Manager only.
- Internet TCP 80 -> NPM only when needed for ACME; otherwise redirect/disable.
- Internet TCP 8080 -> BLOCK.
- LAN/VPN -> backend TCP 8080 as required.
- LAN/VPN -> NPM management UI only from an administrator network.
