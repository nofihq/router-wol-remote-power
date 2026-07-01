# Tailscale Setup

Tailscale is the private network path. The phone should reach the router and
PC through Tailscale, not through public WAN port forwarding.

## Devices To Add

Add these devices to the same tailnet:

- iPhone
- PC
- router

If the router cannot run Tailscale or another private VPN endpoint, see
[Router Support](router-support.md). The fallback is another already-on LAN
device that can run Tailscale and send WOL on the same LAN as the PC, but the
intended path is router-first.

## PC

Install Tailscale from the official Tailscale install instructions for your
Linux distribution.

Official install page:

```text
https://tailscale.com/install
```

After signing in:

```bash
tailscale status
tailscale ip -4
```

Copy the PC Tailscale IPv4 address into:

```text
<PC_TAILSCALE_IP>
```

The PC API binds to this address on port `8081`.

## iPhone

Install Tailscale from the iOS App Store.

On the iPhone:

1. Open Tailscale.
2. Sign in to the same tailnet as the PC.
3. Confirm the iPhone shows as connected.
4. Leave Tailscale connected before running Shortcuts from cellular or outside
   Wi-Fi.

## Router

The router must have a Tailscale/private IP if the phone will call the wake API
directly.

On the router:

```sh
tailscale status
tailscale ip -4
```

Copy that address into:

```text
<ROUTER_TAILSCALE_IP>
```

The router wake API binds to this address on port `8080`.

## Settings You Do Not Need

This project does not require:

- public WAN port forwarding
- Tailscale Funnel
- Tailscale Serve
- exit nodes
- subnet routes
- MagicDNS

MagicDNS can be convenient, but Tailscale IP addresses are simpler for iOS
Shortcuts.

## Recommended Access Control

By default, many tailnets allow devices to reach each other. For tighter
security, restrict access so only your phone can call:

```text
<ROUTER_TAILSCALE_IP>:8080
<PC_TAILSCALE_IP>:8081
```

Use Tailscale access controls in the admin console. Tailscale currently
supports policy-based access controls through ACLs/grants. The exact policy
syntax depends on how your tailnet is managed, so treat this as the intent:

```text
iPhone -> router:8080
iPhone -> PC:8081
```

Do not allow public internet access to these ports.

## Values To Copy

| Value | Where it goes |
| --- | --- |
| PC Tailscale IPv4 | `<PC_TAILSCALE_IP>` |
| router Tailscale IPv4 | `<ROUTER_TAILSCALE_IP>` |
| phone identity/device | Tailscale access-control source if using ACLs/grants |

## Quick Test

From any device on the same tailnet, after the APIs are installed:

```bash
curl -H "Authorization: Bearer <TOKEN>" http://<PC_TAILSCALE_IP>:8081/status
curl -H "Authorization: Bearer <TOKEN>" http://<ROUTER_TAILSCALE_IP>:8080/wake
```
