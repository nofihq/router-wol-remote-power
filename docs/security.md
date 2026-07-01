# Security Model

This project is designed for private tailnet use, not public internet exposure.

## Recommended Defaults

- Bind the router API to the router's Tailscale IP when the router OS supports
  that reliably.
- On ASUSWRT-Merlin/Tailscale userspace setups where Tailscale delivers traffic
  locally, use `ROUTER_LISTEN_IP=0.0.0.0` only with firewall rules and
  `ROUTER_ALLOWED_CLIENT_NETS` limiting sources to loopback/Tailscale networks.
- Bind the PC API to the PC's Tailscale IP.
- Do not forward router WAN ports to either API.
- Use a strong random bearer token.
- Use separate router and PC tokens if you want compromise of one endpoint to
  avoid authorizing the other endpoint.
- Store token files outside git with mode `0600`, owned by the root-run service
  or by the non-root service user that must read the token.
- Prefer Tailscale ACLs that allow only your phone to reach the API ports.
- Keep sudoers entries limited to fixed root-owned helper scripts.
- Keep `/usr/local/sbin/pc_*_with_wol` owned by root and not writable by the API
  user.
- If host or router firewalls are used, allow router `8080` from the
  Tailscale/private path and loopback when needed, then drop other sources for
  that port. Allow PC `8081` only on the PC's Tailscale/private interface.
- Use separate tokens for `/wake` and `/shutdown`/`/suspend` when practical.

## Safe Network Shape

```text
iPhone -> Tailscale/private VPN -> router /wake
iPhone -> Tailscale/private VPN -> PC /status /suspend /shutdown
router -> local wired LAN -> WOL packet to PC
```

## ASUSWRT-Merlin Firewall Ordering

On some ASUSWRT-Merlin/Tailscale setups, the request that reaches the wake API
can appear as local or loopback traffic on the router. In that case, a firewall
rule that only allows `tailscale0` may make the iPhone Shortcut hang even while
the service is running.

Use this rule order for router port `8080`:

1. allow loopback for `8080`
2. allow the Tailscale/private interface for `8080`
3. drop other sources for `8080`
4. do not add a WAN allow or port-forward rule

The app still requires the bearer token, and `ROUTER_ALLOWED_CLIENT_NETS` should
also restrict source addresses when `ROUTER_LISTEN_IP=0.0.0.0`.

Unsafe network shape:

```text
public internet -> router WAN port forward -> power API
```

## Threats To Care About

- A leaked bearer token lets an attacker wake, suspend, or shut down the PC if
  they can also reach the API.
- A compromised tailnet device may be able to call the APIs unless ACLs prevent
  it.
- A weak RustDesk unattended password can expose the desktop session.
- Publishing real Tailscale IPs, LAN IPs, MAC addresses, or tokens makes later
  mistakes easier.
- Root helper scripts must be root-owned and not writable by the API user.
- The bearer token is authorization, not identity. Pair it with Tailscale ACLs
  where possible.
- GET requests are easy for iOS Shortcuts, but they are still state-changing
  actions. Do not expose these endpoints outside the tailnet.

## Not Covered

- This does not harden RustDesk itself.
- This does not replace full disk encryption.
- This does not guarantee suspend works on every Linux/NVIDIA/ACPI combination.
