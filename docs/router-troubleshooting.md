# Router Wake Troubleshooting

Use this guide when `PC SUSPEND` works but `PC ON` is slow, intermittent, or
times out. Do not start by changing Linux suspend, Ethernet, or UEFI settings.
`PC SUSPEND` talks to the PC, while `PC ON` talks to the router. They can fail
independently.

## First Identify Which Request Failed

If `PC ON` never returns `Wake packet sent`, check the phone-to-router path.

If it returns `Wake packet sent` but the PC stays asleep or off, check the
router's WOL command, LAN interface, target MAC, Ethernet WOL state, and UEFI
wake settings.

If the PC only shows a black screen and never completed suspend, use
[Linux Suspend Troubleshooting](linux-suspend-troubleshooting.md) instead.

## Check Tailscale On All Three Devices

On the phone, confirm Tailscale is connected.

On the PC:

```bash
tailscale status
tailscale ping -c 1 <ROUTER_TAILSCALE_IP>
```

On the router:

```sh
tailscale status
tailscale ip -4
tailscale version
```

`NeedsLogin`, `Logged out`, or no Tailscale IP means that device must sign in
again. After the PC and router are healthy, disable key expiry for those two
unattended devices in the Tailscale Machines page.

Run repeated checks instead of trusting one successful request:

```bash
for n in 1 2 3 4 5; do
  tailscale ping -c 1 <ROUTER_TAILSCALE_IP>
done
```

## Check The Router Wake API

On the router:

```sh
/opt/etc/init.d/S99wake-api status
netstat -lnt | grep ':8080'
```

From another tailnet device:

```bash
curl -m 5 \
  -H "Authorization: Bearer <ROUTER_TOKEN>" \
  http://<ROUTER_TAILSCALE_IP>:8080/wake
```

Expected result:

```text
Wake packet sent
```

If Tailscale ping is reliable but TCP port `8080` is not, check the Merlin
loopback/firewall rule order in [Security](security.md), the wake API process,
and the router's Tailscale version.

## Check Router-To-PC Dispatcher Reachability

This section applies when the router handles `/status`, `/suspend`, or
`/shutdown` for multiple operating systems.

From the router, test ordinary TCP to every configured PC target. A successful
`tailscale ping` does not prove router programs can open Tailnet sockets:

```sh
python3 -c 'import socket; socket.create_connection(("<PC_TARGET_IP>", 8081), 3).close()'
```

If Tailnet ping works but this connection times out and `ip route get
<PC_TAILSCALE_IP>` points toward the WAN, the router is likely using a
userspace Tailscale integration. Do not change the PC's Ethernet or Wi-Fi
routes. Use each OS's reserved wired LAN IP in `PC_API_TARGETS`, configure its
PC API for router-relay mode, and restrict LAN sources to `<ROUTER_LAN_IP>/32`.

Confirm the read-only status path before testing a power action:

```sh
curl -H "Authorization: Bearer <PC_TOKEN>" \
  http://<ROUTER_TAILSCALE_IP>:8080/status
```

The router log should show which target handled `/status`. A timeout means the
target is unreachable. HTTP `403` means the OS and router dispatcher are using
different PC tokens.

## Check USB-Backed Entware Storage

This section applies when `/opt` is stored on USB, which is common on
ASUSWRT-Merlin.

Confirm the mount:

```sh
mount | grep routerusb
df -h /opt
```

Test actual reads:

```sh
dd if=/opt/bin/tailscale of=/dev/null bs=1048576
dd if=/opt/bin/tailscaled of=/dev/null bs=1048576
```

Both commands should finish promptly. A large virtual-memory number for a Go
program is not proof of a memory problem. Stronger evidence of a storage stall
is:

- a process stuck in `D` state
- `/proc/<PID>/wchan` showing `sync_page`
- the USB-storage worker waiting in `usb_sg_wait`
- the in-flight I/O field in `/proc/diskstats` staying nonzero while commands
  hang

Do not unplug a mounted USB drive while the router is running.

## Safe Recovery Order

Use this order while physically present or with a tested recovery path:

1. Save copies of the router Tailscale state, wake API files, token, environment
   file, and init scripts.
2. Restart only Tailscale and retest.
3. If USB reads or Tailscale commands remain stuck, perform a normal router
   reboot. Do not factory-reset it.
4. Wait for normal Wi-Fi, internet, Tailscale, and the wake API to return.
5. Run repeated Tailscale, API, and USB-read tests.
6. If USB stalls return after reboot, replace the USB drive and restore the
   saved Entware configuration.

A reboot can clear a controller lockup, but it does not prove the flash drive
is healthy. Repeated stalls after reboot are the reason to replace the drive.

## Updating Router Tailscale Safely

Prefer the router platform's maintained package when it is current. If its
package is years behind:

1. Record `uname -m` and the existing `tailscale version`.
2. Back up both Tailscale binaries, the state file, and the init script.
3. Download the matching official stable build on a workstation.
4. Verify the archive against Tailscale's published SHA-256 value.
5. Copy it to a staging directory on the router.
6. Run staged `tailscale version` and `tailscaled --version` before replacing
   anything.
7. Stop only the Tailscale daemon, replace both binaries, and start it again.
8. Confirm the original Tailscale IP returns.
9. Run repeated ping and authenticated wake-API tests.
10. Keep the old binaries and state until the new version survives a reboot.

Do not update router firmware, Tailscale, Entware, and the wake API all at once.
One change at a time leaves a clear rollback path.
