# Configuration Values

Collect these values before installing anything. Replace every placeholder in
the setup guide with your own values.

## Required Values

| Placeholder | What it is | How to find it | Used by |
| --- | --- | --- | --- |
| `<PC_TAILSCALE_IP>` | PC's Tailscale IPv4 address | Run `tailscale ip -4` on the PC | iOS shortcuts, PC API bind address, tests |
| `<ROUTER_TAILSCALE_IP>` | Router or relay Tailscale/private IPv4 address | Run `tailscale ip -4` on the router/relay | iOS wake shortcut, router API bind address |
| `<PC_WIRED_INTERFACE>` | PC's wired Ethernet interface name | Run `ip link show` on the PC. Common examples: `eno1`, `enp3s0`, `eth0` | PC suspend/shutdown helpers |
| `<PC_ETHERNET_MAC>` | PC's wired Ethernet MAC address | Run `ip link show <PC_WIRED_INTERFACE>` | Router WOL command |
| `<LAN_BRIDGE_IFACE>` | Router LAN bridge/interface that reaches the PC | Router-specific. Common ASUSWRT-Merlin value: `br0` | Router WOL command |
| `<PATH_TO_ETHER_WAKE>` | Path to the router/relay WOL command | Run `command -v ether-wake` or find the equivalent WOL tool | Router wake API |
| `<LINUX_USER>` | Linux user that runs the PC API service | Run `whoami` on the PC, or choose a dedicated service user | systemd service, sudoers, token file path |
| `<TOKEN>` | Strong random bearer token | Run `openssl rand -base64 32` | iOS shortcuts, PC API, router API |
| `<ROUTER_SSH_USER>` | SSH username for the router/relay | Router-specific | Copying router files |
| `<ROUTER_LAN_IP>` | Router's LAN management IP | Router web UI or `ip route` default gateway | Copying router files |
| RustDesk PC ID | RustDesk's ID for the PC | Open RustDesk on the PC | RustDesk app on phone |
| RustDesk permanent password | Unattended-access password | Set in RustDesk security settings on the PC | RustDesk app on phone |

## Recommended Values

| Placeholder | What it is | Why it helps |
| --- | --- | --- |
| Reserved PC LAN IP | DHCP reservation for the PC's wired NIC | Makes LAN troubleshooting easier, though WOL uses the MAC address |
| Separate router token | Token only for `/wake` | Limits damage if one token leaks |
| Separate PC token | Token only for `/status`, `/suspend`, `/shutdown` | Limits damage if one token leaks |

## Do Not Use

- The Wi-Fi MAC address for WOL.
- A public WAN IP for any shortcut.
- A token in the URL query string.
- A token committed to git.
- WAN port forwarding to either API.
- RustDesk passwords committed to git.

## Quick Sanity Check

The phone calls:

```text
http://<ROUTER_TAILSCALE_IP>:8080/wake
http://<PC_TAILSCALE_IP>:8081/suspend
http://<PC_TAILSCALE_IP>:8081/shutdown
http://<PC_TAILSCALE_IP>:8081/status
```

The router sends WOL to:

```text
<PC_ETHERNET_MAC> on <LAN_BRIDGE_IFACE>
```

The PC helpers re-enable WOL on:

```text
<PC_WIRED_INTERFACE>
```
