# Cloudflare

Use Cloudflare DNS for the public hostname. Proxy the record when desired. Restrict origin access at the firewall to NGINX Proxy Manager. Configure `TRUSTED_PROXY_CIDRS` with only proxy networks you actually control. Do not trust `CF-Connecting-IP` or `X-Forwarded-For` from arbitrary Internet clients.
