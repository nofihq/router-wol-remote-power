# Configuration Values

Collect these values before installing anything. Replace every placeholder in
the setup guide with your own values.

## Required Values

| Placeholder | What it is | How to find it | Used by |
| --- | --- | --- | --- |
| `<PC_TAILSCALE_IP>` | Active OS's Tailscale IPv4 address | Run `tailscale ip -4` on Linux or Windows; dual-boot installations normally have different addresses | iOS shortcuts, PC API bind address, tests |
| `<PC_LISTEN_IP>` | Address where one OS's PC API listens | Use its Tailscale IP in direct mode or wired LAN IP in router-relay mode | Windows installer, status tests, direct shortcuts |
| `<PC_API_REACHABLE_IP>` | One PC API target reachable by an ordinary router process | Use that OS's Tailscale IP when router-originated Tailnet TCP works; otherwise use its reserved wired LAN IP | Router dispatcher reachability test |
| `<LINUX_PC_LAN_IP>` | Linux wired LAN IPv4 address | Run `ip -4 address show` on Linux; reserve it in router DHCP | Router relay when the router cannot originate Tailnet TCP |
| `<LINUX_PC_TAILSCALE_IP>` | Linux installation's Tailscale IPv4 address | Boot Linux and run `tailscale ip -4` | Optional router dual-boot dispatcher |
| `<WINDOWS_PC_TAILSCALE_IP>` | Windows installation's Tailscale IPv4 address | Boot Windows and run `tailscale ip -4` | Optional router dual-boot dispatcher |
| `<WINDOWS_PC_LAN_IP>` | Windows wired LAN IPv4 address | Run `Get-NetIPConfiguration` in Windows; reserve it in router DHCP | Optional router-relay mode |
| `<LINUX_PC_REACHABLE_IP>` | Linux address reachable from the router | Use the Linux Tailscale IP on kernel-routed Tailnet routers, or its reserved LAN IP in router-relay mode | Router dual-boot dispatcher |
| `<WINDOWS_PC_REACHABLE_IP>` | Windows address reachable from the router | Use the Windows Tailscale IP on kernel-routed Tailnet routers, or its reserved LAN IP in router-relay mode | Router dual-boot dispatcher |
| `<ROUTER_TAILSCALE_IP>` | Router Tailscale/private IPv4 address | Run `tailscale ip -4` on the router | iOS wake shortcut, router API bind address |
| `<ROUTER_LISTEN_IP>` | Router API bind address | Usually `<ROUTER_TAILSCALE_IP>`. On ASUSWRT-Merlin/Tailscale userspace setups, use `0.0.0.0` with firewall and app allowlist controls | Router wake API bind address |
| `<ROUTER_ALLOWED_CLIENT_NETS>` | Optional client source networks for the router API | Merlin fallback example: `127.0.0.0/8,::1,100.64.0.0/10,fd7a:115c:a1e0::/48` | Router wake API app-layer source allowlist |
| `<PC_WIRED_INTERFACE>` | Linux wired Ethernet interface name | Run `ip link show` on the PC. Common examples: `eno1`, `enp3s0`, `eth0` | Linux suspend/shutdown helpers |
| `<PC_ETHERNET_MAC>` | PC's wired Ethernet MAC address | Run `ip link show <PC_WIRED_INTERFACE>` | Router WOL command |
| `<LAN_BRIDGE_IFACE>` | Router LAN bridge/interface that reaches the PC | Router-specific. Common ASUSWRT-Merlin value: `br0` | Router WOL command |
| `<PATH_TO_ETHER_WAKE>` | Path to the router WOL command | Run `command -v ether-wake` or find the equivalent WOL tool | Router wake API |
| `<PATH_TO_TAILSCALE>` | Router path to the Tailscale CLI | Run `command -v tailscale` on the router | Router init/service environment |
| `<LINUX_USER>` | Linux user that runs the PC API service | Run `whoami` on the PC, or choose a dedicated service user | Linux systemd service, sudoers, token file path |
| `<WIFI_INTERFACE>` | Linux Wi-Fi interface used only by an optional diagnosed suspend workaround | Run `ip link show`; common examples are `wlan0` and `wlp2s0` | Optional Linux systemd sleep hook configuration |
| `<PC_TOKEN>` | Strong random bearer token for the PC API | Run `openssl rand -base64 32` | PC suspend/shutdown shortcuts and PC API |
| `<ROUTER_TOKEN>` | Strong random bearer token for the router wake API | Run `openssl rand -base64 32` | PC ON shortcut and router API |
| `<ROUTER_SSH_USER>` | SSH username for the router | Router-specific | Copying router files |
| `<ROUTER_LAN_IP>` | Router's LAN management IP | Router web UI or `ip route` default gateway | Copying router files |
| RustDesk PC ID | RustDesk's ID for the PC | Open RustDesk on the PC | RustDesk app on phone |
| RustDesk permanent password | Unattended-access password | Set in RustDesk security settings on the PC | RustDesk app on phone |

## Recommended Values

| Placeholder | What it is | Why it helps |
| --- | --- | --- |
| Reserved PC LAN IP | DHCP reservation for the PC's wired NIC | Makes LAN troubleshooting easier, though WOL uses the MAC address |
| Shared dual-boot PC token | One PC token used by Linux, Windows, and the router dispatcher | Lets one dispatcher authenticate to whichever OS is running; keep the router wake token separate |

## Do Not Use

- The Wi-Fi MAC address for WOL.
- A public WAN IP for any shortcut.
- A token in the URL query string.
- A token committed to git.
- WAN port forwarding to either API.
- RustDesk passwords committed to git.

## Quick Sanity Check

For one OS in direct mode, the phone calls:

```text
http://<ROUTER_TAILSCALE_IP>:8080/wake
http://<PC_TAILSCALE_IP>:8081/suspend
http://<PC_TAILSCALE_IP>:8081/shutdown
http://<PC_TAILSCALE_IP>:8081/status
```

For a dual-boot PC with one automatic shortcut set, the phone calls:

```text
PC ON:      http://<ROUTER_TAILSCALE_IP>:8080/wake      with <ROUTER_TOKEN>
PC SUSPEND: http://<ROUTER_TAILSCALE_IP>:8080/suspend   with <PC_TOKEN>
PC OFF:     http://<ROUTER_TAILSCALE_IP>:8080/shutdown  with <PC_TOKEN>
```

Do not mix direct PC power URLs and router-dispatcher power URLs unless you
intentionally maintain separate shortcut sets.

The router always sends WOL to:

```text
<PC_ETHERNET_MAC> on <LAN_BRIDGE_IFACE>
```

With the optional dispatcher, the router also forwards authenticated power
requests to the first reachable address in `PC_API_TARGETS`.

On Linux, the PC helpers re-enable WOL on:

```text
<PC_WIRED_INTERFACE>
```
