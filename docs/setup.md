# End-To-End Setup Guide

This is the implementation guide. If you are not sure what Wake-on-LAN,
Tailscale, router scripts, or OS background services are, read
[Start Here](start-here.md) first.

This page gives the Linux/systemd installation. For Windows, follow
[Windows Setup](windows-setup.md); the router and phone sections of this guide
remain the same.

Replace placeholder values with your own tailnet IPs, LAN interface names, MAC
addresses, and token paths.

If your hardware matches the compatibility checklist and every placeholder is
replaced correctly, these steps should reproduce the workflow. Hardware,
firmware, router firmware, and Linux suspend behavior can still require local
adjustment, so validate in the order shown in the test section before relying
on it remotely.

Before editing files, collect the values listed in
[Configuration Values](configuration-values.md).

For Tailscale and RustDesk app setup, see:

- [Tailscale Setup](tailscale.md)
- [RustDesk Notes](rustdesk.md)

## 0. Workflow Summary

You will end up with:

- **PC ON** iOS Shortcut -> router Tailscale IP -> router sends Ethernet WOL.
- **PC SUSPEND** iOS Shortcut -> PC Tailscale IP -> PC runs an OS suspend.
- **PC OFF** iOS Shortcut -> PC Tailscale IP -> PC shuts down cleanly.
- RustDesk saved on the phone for desktop access after the PC wakes.
- Optional GNOME 2-hour idle suspend.

The phone can be on home Wi-Fi, outside Wi-Fi, or cellular, as long as the phone
is connected to Tailscale and can reach the router/PC tailnet IPs.

The PC API is not available while the PC is asleep or fully off. In those
states, only the router wake API can answer. Direct sleep-to-off is not
supported; the supported transition from sleep is sleep-to-on.

## 1. Compatibility Checklist

PC:

- Wired Ethernet connected.
- Static or reserved LAN IP recommended.
- You know the wired NIC MAC address.
- UEFI/BIOS has Wake-on-LAN/PCIe wake enabled.
- ErP/deep power saving is disabled if it prevents wake from shutdown.
- Boot order returns to the OS that runs the PC API.
- Linux can suspend through `systemctl suspend`.
- NVIDIA users should enable/use NVIDIA's systemd suspend services.
- NVIDIA users should confirm `modinfo nvidia` and `nvidia-smi` work under the
  currently running kernel before testing suspend.

Common PC firmware setting names:

- Enable: `Wake-on-LAN`, `Resume by LAN`, `Power On By PCI-E`, `PCIe Wake`, or
  similar.
- Disable if it blocks wake: `ErP`, `ErP Ready`, `Deep Sleep`, or similar.
- Set boot order so the Linux install that runs this service boots first.

Router:

- Already powered on when the PC is off or suspended.
- Can run a small HTTP service or equivalent private command endpoint.
- Can persist files and start that service after reboot.
- Is on the same LAN broadcast domain/VLAN as the PC wired NIC.
- Can send WOL magic packets, for example with `ether-wake`, `wakeonlan`, or an
  equivalent tool.
- Can run Tailscale or otherwise expose the wake API only through a private
  VPN/network path.

See [Router Support](router-support.md) for router platforms that can work and
fallback options if the router is locked down.

Phone:

- Tailscale installed and connected.
- iOS Shortcuts can make HTTP GET requests with custom headers.

RustDesk:

- RustDesk service runs on the PC.
- A permanent unattended password is set.
- The phone has the PC ID/password saved outside this repository.

## 2. Install Linux PC Prerequisites

On Ubuntu/Debian-style systems:

```bash
sudo apt update
sudo apt install -y git python3 ethtool curl
```

Install and sign in to Tailscale on the PC. Confirm the PC has a tailnet IP:

```bash
tailscale ip -4
```

Install RustDesk and confirm unattended access works locally before depending
on it remotely.

Use [RustDesk Notes](rustdesk.md) for the PC and iPhone setup steps.

Clone this repository on the PC:

```bash
git clone https://github.com/nofihq/router-wol-remote-power.git
cd router-wol-remote-power
```

## 3. Discover Local Values

On the PC:

```bash
ip -o -4 addr show
ip route show default
ip link show
ethtool <PC_WIRED_INTERFACE> | grep -E 'Supports Wake-on|Wake-on'
tailscale ip -4
```

Find the Ethernet MAC from `ip link show <PC_WIRED_INTERFACE>`. Use the wired MAC, not
the Wi-Fi MAC.

On the router:

```sh
tailscale ip -4
which ether-wake
```

Common ASUSWRT-Merlin LAN bridge interface:

```text
br0
```

## 4. Generate Tokens

Use one strong random token for the router API and one different strong random
token for the PC API.

Generate two values and record them privately:

```bash
# Generate the PC token.
openssl rand -base64 32
# Generate the separate router token.
openssl rand -base64 32
```

Use the first as `<PC_TOKEN>` and the second as `<ROUTER_TOKEN>`, or label them
the other way around before continuing. A single shared token can work for a
personal setup, but the guide uses separate tokens because a leaked router
token should not automatically authorize PC suspend/shutdown. For dual boot,
Linux and Windows must use the same `<PC_TOKEN>` as the router dispatcher, but
that PC token remains different from `<ROUTER_TOKEN>`.

Store tokens outside git.

For the PC API, the service user must be able to read the token. A simple
portable option is to store it under that user's home directory:

```bash
sudo -u <LINUX_USER> install -d -m 0700 /home/<LINUX_USER>/.config/phone-wol-power
sudo -u <LINUX_USER> sh -c 'printf "%s\n" "<PC_TOKEN>" > /home/<LINUX_USER>/.config/phone-wol-power/token'
sudo -u <LINUX_USER> chmod 0600 /home/<LINUX_USER>/.config/phone-wol-power/token
```

For the router API, use the router's normal root-owned private storage. On an
ASUSWRT-Merlin/Entware setup this may look like:

```sh
mkdir -p /opt/share/pc-control
printf "%s\n" "<ROUTER_TOKEN>" > /opt/share/pc-control/.token
chmod 0600 /opt/share/pc-control/.token
```

## 5. Linux PC API

In the commands below, replace `<LINUX_USER>` with the Linux account that will
run the PC API service.

Install helper scripts as root-owned files:

```bash
sudo install -o root -g root -m 0755 pc/helpers/pc_poweroff_with_wol /usr/local/sbin/pc_poweroff_with_wol
sudo install -o root -g root -m 0755 pc/helpers/pc_suspend_with_wol /usr/local/sbin/pc_suspend_with_wol
sudo install -o root -g root -m 0755 pc/helpers/phone-wol-power-system-sleep /usr/lib/systemd/system-sleep/phone-wol-power
```

Install sudoers rules:

```bash
sudo cp pc/sudoers.d/phone-wol-power.example /etc/sudoers.d/phone-wol-power
sudo visudo -f /etc/sudoers.d/phone-wol-power
sudo chmod 0440 /etc/sudoers.d/phone-wol-power
sudo visudo -c
```

Inside the sudoers file, replace both `<LINUX_USER>` placeholders before
saving.

Create `/etc/phone-wol-power/pc.env`:

```bash
sudo install -d -o root -g root -m 0755 /etc/phone-wol-power
sudo nano /etc/phone-wol-power/pc.env
```

```text
PC_TAILSCALE_IP=<PC_TAILSCALE_IP>
PC_LISTEN_IP=<PC_TAILSCALE_IP>
PC_API_PORT=8081
PC_ALLOWED_CLIENT_NETS=
AUTH_TOKEN_FILE=/home/<LINUX_USER>/.config/phone-wol-power/token
WIRED_IFACE=<PC_WIRED_INTERFACE>
```

Optional suspend workaround values:

```text
SUSPEND_REQUIRE_LOADED_MODULES=nvidia
SUSPEND_PRE_DOWN_IFACE=<WIFI_INTERFACE>
SUSPEND_PRE_UNLOAD_MODULES=iwlwifi
```

Set `SUSPEND_REQUIRE_LOADED_MODULES=nvidia` on a PC whose display depends on
NVIDIA. It makes both API and local systemd sleep refuse to continue when the
driver is missing after a kernel update. Do not add the interface/module
workaround values unless suspend hangs and you have already confirmed that
Ethernet is the primary route. They are for systems where a specific driver,
commonly Intel `iwlwifi`, blocks clean suspend.

Keep this file root-owned and not writable by the API user:

```bash
sudo chown root:root /etc/phone-wol-power/pc.env
sudo chmod 0644 /etc/phone-wol-power/pc.env
```

Install the API and service:

```bash
sudo install -d -m 0755 /opt/phone-wol-power/pc
sudo install -m 0755 pc/pc_power_api.py /opt/phone-wol-power/pc/pc_power_api.py
sudo cp pc/systemd/pc-power-api.service.example /etc/systemd/system/pc-power-api.service
sudo nano /etc/systemd/system/pc-power-api.service
sudo systemctl daemon-reload
sudo systemctl enable --now pc-power-api.service
```

Inside the systemd service, replace `<LINUX_USER>`. If your Tailscale interface
is not named `tailscale0`, update the `ExecStartPre` line.

Test status:

```bash
curl -H "Authorization: Bearer <PC_TOKEN>" http://<PC_TAILSCALE_IP>:8081/status
```

## 6. Router Wake API

This section shows an ASUSWRT-Merlin/Entware-style install because that is a
common router path. For OpenWrt, DD-WRT, or pfSense/OPNsense, keep the same
shape but use that router platform's package manager, firewall, and service
manager.

If the router cannot run the wake API, a NAS, Home Assistant box, Raspberry Pi,
mini PC, or Linux server that is already on can run the same wake API as a
fallback relay. That works, but it is not the main router-as-already-on design.
The requirements are the same: private reachability, persistent storage, a WOL
command, and no WAN port forwarding.

### ASUSWRT-Merlin Checklist

ASUSWRT-Merlin is one documented router path because it supports user scripts
and Entware on supported models.

USB storage is commonly needed on ASUSWRT-Merlin/Entware because Entware,
Python, Tailscale, `/opt`, and the wake API files usually need persistent
storage that survives router reboot. On router platforms with normal persistent
storage, such as many OpenWrt or pfSense/OPNsense installs, this USB step may
not apply.

In the router web UI:

- `Administration -> System -> Enable SSH`: `LAN only` while setting this up.
- `Administration -> System -> Enable JFFS custom scripts and configs`: `Yes`.
- If JFFS was just enabled for the first time, initialize it and reboot before
  installing scripts.
- Attach USB storage for Entware/persistent `/opt` storage.

On the router over SSH:

- Install/configure Entware.
- Install Python if it is not already available under `/opt/bin/python3`.
- Install/start Tailscale or otherwise provide private-only access to the
  router API.
- Run `tailscale version` and confirm the router is on a currently maintained
  stable release. Do not assume an old Entware package is current.
- Confirm `tailscale ip -4` returns a router tailnet IP.
- Confirm a WOL sender exists, for example `ether-wake`.

On USB-backed Merlin installs, use a reliable flash drive and keep a backup of
the Tailscale state, wake API, environment file, token file, and init scripts.
The router may appear healthy even when USB-backed `/opt` reads are stalling,
because normal routing and Wi-Fi do not depend on those Entware files.

Create a router token file and router env file outside git:

```text
AUTH_TOKEN_FILE=/opt/share/pc-control/.token
ROUTER_TAILSCALE_IP=<ROUTER_TAILSCALE_IP>
ROUTER_LISTEN_IP=<ROUTER_LISTEN_IP>
ROUTER_API_PORT=8080
ROUTER_ALLOWED_CLIENT_NETS=<ROUTER_ALLOWED_CLIENT_NETS>
WOL_LAN_INTERFACE=br0
WOL_TARGET_MAC=<PC_ETHERNET_MAC>
ETHER_WAKE=<PATH_TO_ETHER_WAKE>
TAILSCALE_REQUIRED=yes
TAILSCALE_CMD=<PATH_TO_TAILSCALE>
```

Use these bind values:

- Preferred router bind: `ROUTER_LISTEN_IP=<ROUTER_TAILSCALE_IP>`.
- ASUSWRT-Merlin/Tailscale userspace fallback:
  `ROUTER_LISTEN_IP=0.0.0.0` and
  `ROUTER_ALLOWED_CLIENT_NETS=127.0.0.0/8,::1,100.64.0.0/10,fd7a:115c:a1e0::/48`.

The fallback is for router setups where binding directly to the Tailscale IP is
not reliable. It must be paired with firewall rules that allow loopback and the
Tailscale/private interface, then drop other sources for port `8080`.

Copy the router files from your workstation to the router:

```bash
scp router/router_wake.py router/S99wake-api.example <ROUTER_SSH_USER>@<ROUTER_LAN_IP>:/tmp/
```

Then on the router:

```sh
mkdir -p /opt/share/pc-control /opt/etc/init.d /opt/var/log /opt/var/run
cp /tmp/router_wake.py /opt/share/pc-control/router_wake.py
cp /tmp/S99wake-api.example /opt/etc/init.d/S99wake-api
chmod 0755 /opt/share/pc-control/router_wake.py /opt/etc/init.d/S99wake-api
```

Create `/opt/share/pc-control/router.env` with the preferred direct bind first:

```sh
cat > /opt/share/pc-control/router.env <<'EOF'
AUTH_TOKEN_FILE=/opt/share/pc-control/.token
ROUTER_TAILSCALE_IP=<ROUTER_TAILSCALE_IP>
ROUTER_LISTEN_IP=<ROUTER_TAILSCALE_IP>
ROUTER_API_PORT=8080
ROUTER_ALLOWED_CLIENT_NETS=
WOL_LAN_INTERFACE=br0
WOL_TARGET_MAC=<PC_ETHERNET_MAC>
ETHER_WAKE=<PATH_TO_ETHER_WAKE>
TAILSCALE_REQUIRED=yes
TAILSCALE_CMD=<PATH_TO_TAILSCALE>
EOF
chmod 0600 /opt/share/pc-control/router.env
```

If the preferred direct bind does not work on ASUSWRT-Merlin/Tailscale
userspace, edit only these two lines in `router.env`:

```text
ROUTER_LISTEN_IP=0.0.0.0
ROUTER_ALLOWED_CLIENT_NETS=127.0.0.0/8,::1,100.64.0.0/10,fd7a:115c:a1e0::/48
```

Use the fallback only with the firewall rules below.

### Optional Dual-Boot PC API Dispatcher

Enable this when Linux and Windows have different Tailscale IPs and you want
one set of phone shortcuts. Both PC API installations must use the same strong
`<PC_TOKEN>`.

Store a copy of that PC token on the router, separate from the router wake
token:

```sh
printf "%s\n" "<PC_TOKEN>" > /opt/share/pc-control/.pc-token
chmod 0600 /opt/share/pc-control/.pc-token
```

Add these values to `/opt/share/pc-control/router.env`:

```text
PC_API_TARGETS=http://<LINUX_PC_REACHABLE_IP>:8081,http://<WINDOWS_PC_REACHABLE_IP>:8081
PC_AUTH_TOKEN_FILE=/opt/share/pc-control/.pc-token
PC_API_TIMEOUT_SECONDS=2
```

The order only controls which address is tried first. Only the currently
booted OS should answer.

First test whether the router can originate ordinary TCP to each OS's
Tailscale IP. `tailscale ping` alone is not enough:

```sh
python3 -c 'import socket; socket.create_connection(("<LINUX_PC_TAILSCALE_IP>", 8081), 3).close()'
```

Some embedded/router Tailscale packages run in userspace mode: Tailnet ping and
incoming phone-to-router requests work, but a normal router process cannot open
an outbound Tailnet TCP connection. On such a router, reserve one wired LAN IP
for each OS and use LAN dispatcher targets. For Linux, keep direct phone access
over Tailscale while allowing only the router on LAN:

```text
PC_LISTEN_IP=0.0.0.0
PC_ALLOWED_CLIENT_NETS=127.0.0.0/8,100.64.0.0/10,<ROUTER_LAN_IP>/32
```

Then use:

```text
PC_API_TARGETS=http://<LINUX_PC_LAN_IP>:8081,http://<WINDOWS_PC_LAN_IP>:8081
```

The Linux API refuses a wildcard bind unless `PC_ALLOWED_CLIENT_NETS` is set.
Keep bearer authentication enabled, do not forward port `8081`, and optionally
enforce the same source restrictions in the PC firewall.

If Windows does not run Tailscale, its target may instead use a reserved wired
LAN IP, for example `http://<WINDOWS_PC_LAN_IP>:8081`. Install the Windows API
in router-relay mode and limit its firewall rule to `<ROUTER_LAN_IP>`.

Restart the router API after changing the environment:

```sh
/opt/etc/init.d/S99wake-api restart
```

The dispatcher is optional. If `PC_API_TARGETS` is unset or empty, the router
continues to expose only `/wake`, exactly as before.

Find `<PATH_TO_ETHER_WAKE>` with:

```sh
command -v ether-wake
```

Find `<PATH_TO_TAILSCALE>` with:

```sh
command -v tailscale
```

If your router uses a different WOL command, wrap it in a small script that
accepts the same arguments or update `ETHER_WAKE` to the compatible command.

Start the wake API:

```sh
/opt/etc/init.d/S99wake-api start
/opt/etc/init.d/S99wake-api status
```

For persistence across reboot, ensure your Merlin user scripts start Entware
init scripts. A common pattern is a `/jffs/scripts/services-start` or
`/jffs/scripts/post-mount` script that calls:

```sh
/opt/etc/init.d/rc.unslung start
```

Keep the router API reachable only over Tailscale or another private path. Do
not forward a WAN port to it.

On ASUSWRT-Merlin, add persistent firewall rules with `/jffs/scripts/firewall-start`.
The important order is loopback allow, Tailscale/private allow, then drop other
sources for router port `8080`.

Example template:

```sh
#!/bin/sh
API_PORT=8080
TS_IFACE=tailscale0

iptables -C INPUT -i lo -p tcp --dport "$API_PORT" -j ACCEPT 2>/dev/null ||
  iptables -I INPUT 1 -i lo -p tcp --dport "$API_PORT" -j ACCEPT

iptables -C INPUT -i "$TS_IFACE" -p tcp --dport "$API_PORT" -j ACCEPT 2>/dev/null ||
  iptables -I INPUT 2 -i "$TS_IFACE" -p tcp --dport "$API_PORT" -j ACCEPT

iptables -C INPUT -p tcp --dport "$API_PORT" -j DROP 2>/dev/null ||
  iptables -I INPUT 3 -p tcp --dport "$API_PORT" -j DROP
```

Then:

```sh
chmod 0755 /jffs/scripts/firewall-start
/jffs/scripts/firewall-start
```

This handles the Merlin/Tailscale case where the request may be delivered
locally or through loopback. Do not add a WAN allow rule or port-forward rule.

Wake command shape:

```sh
ether-wake -i <LAN_BRIDGE_IFACE> -b <PC_ETHERNET_MAC>
```

Test wake while physically present:

```bash
curl -H "Authorization: Bearer <ROUTER_TOKEN>" http://<ROUTER_TAILSCALE_IP>:8080/wake
```

## 7. iOS Shortcuts

Create these in Shortcuts with **Get Contents of URL**:

For one OS in direct mode:

- `PC ON`: `GET http://<ROUTER_TAILSCALE_IP>:8080/wake`
- `PC SUSPEND`: `GET http://<PC_TAILSCALE_IP>:8081/suspend`
- `PC OFF`: `GET http://<PC_TAILSCALE_IP>:8081/shutdown`
- optional `PC STATUS`: `GET http://<PC_TAILSCALE_IP>:8081/status`

For a dual-boot PC with the optional dispatcher enabled, use `PC ON` above but
replace the three direct PC URLs with:

- `PC SUSPEND`: `GET http://<ROUTER_TAILSCALE_IP>:8080/suspend`
- `PC OFF`: `GET http://<ROUTER_TAILSCALE_IP>:8080/shutdown`
- `PC STATUS`: `GET http://<ROUTER_TAILSCALE_IP>:8080/status`

Keep the `<PC_TOKEN>` authorization header for those three routes. `PC ON`
continues to use `<ROUTER_TOKEN>`. Do not mix direct and dispatcher power URLs
in one shortcut set.

Use these authorization headers:

```text
PC ON:      Authorization: Bearer <ROUTER_TOKEN>
PC SUSPEND: Authorization: Bearer <PC_TOKEN>
PC OFF:     Authorization: Bearer <PC_TOKEN>
PC STATUS:  Authorization: Bearer <PC_TOKEN>
```

## 8. RustDesk Unattended Access

On the PC:

1. Install RustDesk.
2. Start/enable the RustDesk service.
3. Set a permanent password for unattended access.
4. Record the RustDesk ID privately.

On the phone:

1. Save the PC's RustDesk ID.
2. Save the unattended password in the RustDesk client or your private phone
   workflow.
3. Do not put the ID/password in this repository.

After waking the PC, give Tailscale and RustDesk a short time to reconnect
before opening the RustDesk session.

## 9. Test

For one OS in direct mode, test read-only status from a tailnet device:

```bash
curl -H "Authorization: Bearer <PC_TOKEN>" http://<PC_TAILSCALE_IP>:8081/status
curl -H "Authorization: Bearer <ROUTER_TOKEN>" http://<ROUTER_TAILSCALE_IP>:8080/wake
```

For dual-boot dispatcher mode, test the full read-only forwarding path instead:

```bash
curl -H "Authorization: Bearer <PC_TOKEN>" http://<ROUTER_TAILSCALE_IP>:8080/status
curl -H "Authorization: Bearer <ROUTER_TOKEN>" http://<ROUTER_TAILSCALE_IP>:8080/wake
```

Only test suspend and shutdown while you have a recovery path. Use the direct
PC URLs for single-OS mode:

```bash
curl -H "Authorization: Bearer <PC_TOKEN>" http://<PC_TAILSCALE_IP>:8081/suspend
curl -H "Authorization: Bearer <PC_TOKEN>" http://<PC_TAILSCALE_IP>:8081/shutdown
```

For dual-boot dispatcher mode, use the router URLs:

```bash
curl -H "Authorization: Bearer <PC_TOKEN>" http://<ROUTER_TAILSCALE_IP>:8080/suspend
curl -H "Authorization: Bearer <PC_TOKEN>" http://<ROUTER_TAILSCALE_IP>:8080/shutdown
```

Recommended validation order:

1. Disable Tailscale key expiry for the unattended router and PC after both are
   signed in and healthy.
2. Confirm `/status` returns `ON`.
3. Confirm at least five consecutive `tailscale ping` checks reach the router.
4. Confirm at least five consecutive router API requests return promptly.
5. Confirm router `/wake` wakes the PC from shutdown.
6. Confirm local `systemctl suspend` works and wakes by keyboard/power button.
7. Confirm `/suspend` sleeps the PC from the phone.
8. Confirm `/wake` wakes it again from the phone.
9. Confirm RustDesk reconnects.
10. Confirm `/shutdown` powers it off cleanly.
11. Confirm `/wake` powers it back on.

If PC sleep works but `PC ON` times out, do not immediately change PC suspend,
Ethernet, or UEFI settings. The failure may be between the phone and router.
Use [Router Wake Troubleshooting](router-troubleshooting.md) to separate the
router path from the PC WOL path.

## 10. Idle Suspend

For GNOME desktops:

```bash
./scripts/configure_idle_suspend.sh --enable-2h
```

Disable:

```bash
./scripts/configure_idle_suspend.sh --disable
```
