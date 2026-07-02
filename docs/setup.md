# End-To-End Setup Guide

This is the implementation guide. If you are not sure what Wake-on-LAN,
Tailscale, router scripts, or Linux services are, read
[Start Here](start-here.md) first.

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
- **PC SUSPEND** iOS Shortcut -> PC Tailscale IP -> PC runs systemd suspend.
- **PC OFF** iOS Shortcut -> PC Tailscale IP -> PC reasserts WOL and powers off.
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

## 2. Install PC Prerequisites

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
git clone https://github.com/<OWNER>/router-wol-remote-power.git
cd router-wol-remote-power
```

## 3. Discover Local Values

On the PC:

```bash
ip -o -4 addr show
ip route show default
ip link show
ethtool <WIRED_IFACE> | grep -E 'Supports Wake-on|Wake-on'
tailscale ip -4
```

Find the Ethernet MAC from `ip link show <WIRED_IFACE>`. Use the wired MAC, not
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
openssl rand -base64 32
openssl rand -base64 32
```

Use the first as `<PC_TOKEN>` and the second as `<ROUTER_TOKEN>`, or label them
the other way around before continuing. A single shared token can work for a
personal setup, but the guide uses separate tokens because a leaked router
token should not automatically authorize PC suspend/shutdown.

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

## 5. PC API

In the commands below, replace `<LINUX_USER>` with the Linux account that will
run the PC API service.

Install helper scripts as root-owned files:

```bash
sudo install -o root -g root -m 0755 pc/helpers/pc_poweroff_with_wol /usr/local/sbin/pc_poweroff_with_wol
sudo install -o root -g root -m 0755 pc/helpers/pc_suspend_with_wol /usr/local/sbin/pc_suspend_with_wol
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
PC_API_PORT=8081
AUTH_TOKEN_FILE=/home/<LINUX_USER>/.config/phone-wol-power/token
WIRED_IFACE=<PC_WIRED_INTERFACE>
```

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
- Confirm `tailscale ip -4` returns a router tailnet IP.
- Confirm a WOL sender exists, for example `ether-wake`.

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

- `PC ON`: `GET http://<ROUTER_TAILSCALE_IP>:8080/wake`
- `PC SUSPEND`: `GET http://<PC_TAILSCALE_IP>:8081/suspend`
- `PC OFF`: `GET http://<PC_TAILSCALE_IP>:8081/shutdown`
- optional `PC STATUS`: `GET http://<PC_TAILSCALE_IP>:8081/status`

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

From a tailnet device:

```bash
curl -H "Authorization: Bearer <PC_TOKEN>" http://<PC_TAILSCALE_IP>:8081/status
curl -H "Authorization: Bearer <ROUTER_TOKEN>" http://<ROUTER_TAILSCALE_IP>:8080/wake
```

Only test suspend and shutdown while you have a recovery path:

```bash
curl -H "Authorization: Bearer <PC_TOKEN>" http://<PC_TAILSCALE_IP>:8081/suspend
curl -H "Authorization: Bearer <PC_TOKEN>" http://<PC_TAILSCALE_IP>:8081/shutdown
```

Recommended validation order:

1. Confirm `/status` returns `ON`.
2. Confirm router `/wake` wakes the PC from shutdown.
3. Confirm local `systemctl suspend` works and wakes by keyboard/power button.
4. Confirm `/suspend` sleeps the PC from the phone.
5. Confirm `/wake` wakes it again from the phone.
6. Confirm RustDesk reconnects.
7. Confirm `/shutdown` powers it off cleanly.
8. Confirm `/wake` powers it back on.

## 10. Idle Suspend

For GNOME desktops:

```bash
./scripts/configure_idle_suspend.sh --enable-2h
```

Disable:

```bash
./scripts/configure_idle_suspend.sh --disable
```
