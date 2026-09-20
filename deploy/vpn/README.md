# VPN

Set `VPN_CIDRS` to your actual WireGuard/OpenVPN/private CIDRs. Keep administration endpoints private. The backend exposes authenticated `/api/v1/self-hosting/status` and rejects that endpoint when the source address is outside the configured VPN/private networks.
