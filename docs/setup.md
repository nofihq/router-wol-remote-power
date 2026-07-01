# End-To-End Setup Guide

This is a template-level guide. Replace placeholder values with your own
tailnet IPs, LAN interface names, MAC addresses, and token paths.

If your hardware matches the compatibility checklist and every placeholder is
replaced correctly, these steps should reproduce the workflow. Hardware,
firmware, router firmware, and Linux suspend behavior can still require local
adjustment, so validate in the order shown in the test section before relying
on it remotely.

Before editing files, collect the values listed in
[Configuration Values](configuration-values.md).

## 0. Workflow Summary

You will end up with:

- **PC ON** iOS Shortcut -> router Tailscale IP -> router sends Ethernet WOL.
- **PC SUSPEND** iOS Shortcut -> PC Tailscale IP -> PC runs systemd suspend.
- **PC OFF** iOS Shortcut -> PC Tailscale IP -> PC reasserts WOL and powers off.
- RustDesk saved on the phone for desktop access after the PC wakes.
- Optional GNOME 2-hour idle suspend.

The phone can be on home Wi-Fi, outside Wi-Fi, or cellular, as long as the phone
is connected to Tailscale and can reach the router/PC tailnet IPs.

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

Router or relay device:

- Already powered on when the PC is off or suspended.
- Can run a small HTTP service or equivalent private command endpoint.
- Can persist files and start that service after reboot.
- Is on the same LAN broadcast domain/VLAN as the PC wired NIC.
- Can send WOL magic packets, for example with `ether-wake`, `wakeonlan`, or an
  equivalent tool.
- Can run Tailscale or otherwise expose the wake API only through a private
  VPN/network path.

See [Router Support](router-support.md) for vendor-neutral router examples.

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

Use one strong random token for the router API and one for the PC API, or one
shared token if you accept that tradeoff.

Example:

```bash
openssl rand -base64 32
```

Store tokens outside git.

For the PC API, the service user must be able to read the token. A simple
portable option is to store it under that user's home directory:

```bash
sudo -u <LINUX_USER> install -d -m 0700 /home/<LINUX_USER>/.config/phone-wol-power
sudo -u <LINUX_USER> sh -c 'printf "%s\n" "<TOKEN>" > /home/<LINUX_USER>/.config/phone-wol-power/token'
sudo -u <LINUX_USER> chmod 0600 /home/<LINUX_USER>/.config/phone-wol-power/token
```

For the router API, use the router's normal root-owned private storage. On an
ASUSWRT-Merlin/Entware setup this may look like:

```sh
mkdir -p /opt/share/pc-control
printf "%s\n" "<TOKEN>" > /opt/share/pc-control/.token
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
curl -H "Authorization: Bearer <TOKEN>" http://<PC_TAILSCALE_IP>:8081/status
```

## 6. Router Or Relay API

This section shows an ASUSWRT-Merlin/Entware-style install because that is a
common router path. For OpenWrt, DD-WRT, pfSense/OPNsense, NAS, Home Assistant,
or another Linux relay, use the same environment variables and run
`router/router_wake.py` under that platform's service manager. The requirements
are the same: private reachability, persistent storage, a WOL command, and no
WAN port forwarding.

### ASUSWRT-Merlin Checklist

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
ROUTER_API_PORT=8080
WOL_LAN_INTERFACE=br0
WOL_TARGET_MAC=<PC_ETHERNET_MAC>
ETHER_WAKE=<PATH_TO_ETHER_WAKE>
```

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

Create `/opt/share/pc-control/router.env`:

```sh
cat > /opt/share/pc-control/router.env <<'EOF'
AUTH_TOKEN_FILE=/opt/share/pc-control/.token
ROUTER_TAILSCALE_IP=<ROUTER_TAILSCALE_IP>
ROUTER_API_PORT=8080
WOL_LAN_INTERFACE=br0
WOL_TARGET_MAC=<PC_ETHERNET_MAC>
ETHER_WAKE=<PATH_TO_ETHER_WAKE>
EOF
chmod 0600 /opt/share/pc-control/router.env
```

Find `<PATH_TO_ETHER_WAKE>` with:

```sh
command -v ether-wake
```

If your router uses a different WOL command, wrap it in a small script that
accepts the same arguments or update `ETHER_WAKE` to the compatible command.

Start the wake API:

```sh
/opt/etc/init.d/S99wake-api start
```

For persistence across reboot, ensure your Merlin user scripts start Entware
init scripts. A common pattern is a `/jffs/scripts/services-start` or
`/jffs/scripts/post-mount` script that calls:

```sh
/opt/etc/init.d/rc.unslung start
```

Keep the router API reachable only over Tailscale or another private path. Do
not forward a WAN port to it.

If your router firewall blocks local services by default, allow the API port
only on the Tailscale/private interface. Do not add a WAN allow rule.

Wake command shape:

```sh
ether-wake -i <LAN_BRIDGE_IFACE> -b <PC_ETHERNET_MAC>
```

Test wake while physically present:

```bash
curl -H "Authorization: Bearer <TOKEN>" http://<ROUTER_TAILSCALE_IP>:8080/wake
```

## 7. iOS Shortcuts

Create these in Shortcuts with **Get Contents of URL**:

- `PC ON`: `GET http://<ROUTER_TAILSCALE_IP>:8080/wake`
- `PC SUSPEND`: `GET http://<PC_TAILSCALE_IP>:8081/suspend`
- `PC OFF`: `GET http://<PC_TAILSCALE_IP>:8081/shutdown`
- optional `PC STATUS`: `GET http://<PC_TAILSCALE_IP>:8081/status`

Each uses:

```text
Authorization: Bearer <TOKEN>
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
curl -H "Authorization: Bearer <TOKEN>" http://<PC_TAILSCALE_IP>:8081/status
curl -H "Authorization: Bearer <TOKEN>" http://<ROUTER_TAILSCALE_IP>:8080/wake
```

Only test suspend and shutdown while you have a recovery path:

```bash
curl -H "Authorization: Bearer <TOKEN>" http://<PC_TAILSCALE_IP>:8081/suspend
curl -H "Authorization: Bearer <TOKEN>" http://<PC_TAILSCALE_IP>:8081/shutdown
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
