# NGINX Proxy Manager

Create a Proxy Host for `SERVER_PUBLIC_URL` and point it to the backend's private LAN/VPN address and port 8080. Enable WebSocket support. Terminate Let's Encrypt TLS at NPM. Add the `X-Streaming-Proxy-Key` header with the same random value as `PROXY_SHARED_SECRET`.

Only expose NPM's TCP 443 (and TCP 80 if needed for ACME HTTP validation) through the router. Do not expose Dart port 8080.
