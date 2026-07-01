# End-To-End Setup Guide

This is a template-level guide. Replace placeholder values with your own
tailnet IPs, LAN interface names, MAC addresses, and token paths.

If your hardware matches the compatibility checklist and every placeholder is
replaced correctly, these steps should reproduce the workflow. Hardware,
firmware, router firmware, and Linux suspend behavior can still require local
adjustment, so validate in the order shown in the test section before relying
on it remotely.

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

Router:

- Router is always on.
- Router can run a small HTTP service.
- Router is on the same LAN broadcast domain as the PC wired NIC.
- Router can send WOL magic packets, for example with `ether-wake`.
- Router can run Tailscale or otherwise expose the wake API only privately.

Phone:

- Tailscale installed and connected.
- iOS Shortcuts can make HTTP GET requests with custom headers.

RustDesk:

- RustDesk service runs on the PC.
- A permanent unattended password is set.
- The phone has the PC ID/password saved outside this repository.

## 2. Discover Local Values

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

## 3. Generate Tokens

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

## 4. PC API

Install helper scripts as root-owned files:

```bash
sudo install -o root -g root -m 0755 pc/helpers/pc_poweroff_with_wol /usr/local/sbin/pc_poweroff_with_wol
sudo install -o root -g root -m 0755 pc/helpers/pc_suspend_with_wol /usr/local/sbin/pc_suspend_with_wol
```

Install sudoers rules:

```bash
sudo cp pc/sudoers.d/phone-wol-power.example /etc/sudoers.d/phone-wol-power
sudo nano /etc/sudoers.d/phone-wol-power
sudo chmod 0440 /etc/sudoers.d/phone-wol-power
sudo visudo -c
```

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

Test status:

```bash
curl -H "Authorization: Bearer <TOKEN>" http://<PC_TAILSCALE_IP>:8081/status
```

## 5. Router API

On the router, install Python and make sure `ether-wake` exists.

Create a router token file and router env file outside git:

```text
AUTH_TOKEN_FILE=/opt/share/pc-control/.token
ROUTER_TAILSCALE_IP=<ROUTER_TAILSCALE_IP>
ROUTER_API_PORT=8080
WOL_LAN_INTERFACE=br0
WOL_TARGET_MAC=<PC_ETHERNET_MAC>
```

For ASUSWRT-Merlin:

1. Enable custom scripts in the router UI.
2. Install/configure Entware if you need Python from `/opt`.
3. Put persistent files under a USB-backed `/opt/share/pc-control` or similar.
4. Adapt `router/S99wake-api.example` for `/opt/etc/init.d/`.
5. Ensure Entware init scripts start from Merlin's `services-start` path.
6. Keep the API reachable only through Tailscale/private router interfaces.

Install `router/router_wake.py` and an init script appropriate for your router
firmware. For ASUSWRT-Merlin with Entware, adapt `router/S99wake-api.example`.

Wake command shape:

```sh
ether-wake -i <LAN_BRIDGE_IFACE> -b <PC_ETHERNET_MAC>
```

Test wake while physically present:

```bash
curl -H "Authorization: Bearer <TOKEN>" http://<ROUTER_TAILSCALE_IP>:8080/wake
```

## 6. iOS Shortcuts

Create these in Shortcuts with **Get Contents of URL**:

- `PC ON`: `GET http://<ROUTER_TAILSCALE_IP>:8080/wake`
- `PC SUSPEND`: `GET http://<PC_TAILSCALE_IP>:8081/suspend`
- `PC OFF`: `GET http://<PC_TAILSCALE_IP>:8081/shutdown`
- optional `PC STATUS`: `GET http://<PC_TAILSCALE_IP>:8081/status`

Each uses:

```text
Authorization: Bearer <TOKEN>
```

## 7. RustDesk Unattended Access

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

## 8. Test

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

## 9. Idle Suspend

For GNOME desktops:

```bash
./scripts/configure_idle_suspend.sh --enable-2h
```

Disable:

```bash
./scripts/configure_idle_suspend.sh --disable
```
