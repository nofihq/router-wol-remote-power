# Security Model

This project is designed for private tailnet use, not public internet exposure.

## Recommended Defaults

- Bind the router API to the router's Tailscale IP when the router OS supports
  that reliably.
- On ASUSWRT-Merlin/Tailscale userspace setups where Tailscale delivers traffic
  locally, use `ROUTER_LISTEN_IP=0.0.0.0` only with firewall rules and
  `ROUTER_ALLOWED_CLIENT_NETS` limiting sources to loopback/Tailscale networks.
- Bind the PC API to the PC's Tailscale IP when the router can reach it.
- For router-relay mode, use a reserved PC LAN IP and a wildcard listener only
  with `PC_ALLOWED_CLIENT_NETS` restricted to Tailnet ranges, loopback, and the
  router's single LAN IP. The API refuses an unrestricted wildcard bind.
- Do not forward router WAN ports to either API.
- Use a strong random bearer token.
- Use separate router and PC tokens if you want compromise of one endpoint to
  avoid authorizing the other endpoint.
- Store token files outside git with mode `0600`, owned by the root-run service
  or by the non-root service user that must read the token.
- Prefer Tailscale ACLs that allow your phone to reach the API ports. If the
  router dispatcher uses PC Tailscale targets, also allow the router to reach
  PC port `8081`.
- Keep sudoers entries limited to fixed root-owned helper scripts.
- Keep `/usr/local/sbin/pc_*_with_wol` owned by root and not writable by the API
  user.
- On Windows, keep `%ProgramData%\phone-wol-power` restricted to `SYSTEM` and
  Administrators. The installer applies those ACLs automatically.
- If host or router firewalls are used, allow router `8080` from the
  Tailscale/private path and loopback when needed, then drop other sources for
  that port. In direct mode, allow PC `8081` only on its Tailscale/private
  interface. In LAN relay mode, additionally allow only the router's LAN IP.
- Use separate tokens for `/wake` and `/shutdown`/`/suspend` when practical.
- If the optional dual-boot dispatcher is enabled, the router stores a copy of
  the PC token and forwards PC power requests. Keep that token file root-owned
  with mode `0600`, and keep the router itself patched and private.
- Windows automatic sign-in is not required for the power API. If it is enabled
  for an unattended desktop application, anyone with physical access can use
  the signed-in session. Never put the Windows password in this repository or
  pass it to Autologon through command-line arguments.

## Safe Network Shape

Direct single-OS mode:

```text
iPhone -> Tailscale/private VPN -> router /wake
iPhone -> Tailscale/private VPN -> PC /status /suspend /shutdown
router -> local wired LAN -> WOL packet
```

Dual-boot dispatcher mode:

```text
iPhone -> Tailscale/private VPN -> router /wake /status /suspend /shutdown
router -> Tailscale or restricted LAN -> active OS API
router -> local wired LAN -> WOL packet
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
- This does not guarantee suspend works on every Linux/NVIDIA/ACPI or Windows
  firmware/driver/power-state combination.
