# Linux Suspend Troubleshooting

Suspend reliability is the part of this workflow most likely to vary by
machine. Test while physically present before relying on remote suspend.

## First Checks

Confirm the system can enter suspend through the same path used by this repo:

```bash
systemctl suspend
```

After resume, inspect the current boot logs:

```bash
journalctl -b --no-pager | grep -Ei 'suspend|resume|nvidia|acpi|wake|failed'
```

If `systemctl suspend` works and direct commands such as `rtcwake -m mem` do
not, prefer the systemd path. GPU drivers, especially NVIDIA, may need
systemd-managed suspend/resume hooks.

## Wake-on-LAN Checks

Confirm the wired NIC supports and has enabled magic-packet wake:

```bash
sudo ethtool <PC_WIRED_INTERFACE> | grep -E 'Supports Wake-on|Wake-on'
sudo ethtool -s <PC_WIRED_INTERFACE> wol g
```

The PC helper scripts reassert `wol g` immediately before suspend and shutdown
because some drivers or power events can reset this setting.

## Firmware Checks

Look for settings with names like:

- Wake-on-LAN
- PCIe wake
- Power on by PCI-E
- Resume by LAN
- ErP
- Deep Sleep

Enable PCIe/LAN wake. Disable ErP/deep sleep if it prevents wake from the
power state you want.

## Common Failure Areas

- NVIDIA suspend services are disabled or bypassed.
- Wi-Fi or Bluetooth drivers fail device suspend.
- USB devices wake the machine immediately or block suspend.
- Firmware exposes only `s2idle`, not deep sleep, or handles deep sleep poorly.
- The Ethernet NIC loses standby power in S5/off.
- Router sends the WOL packet on the wrong interface or VLAN.

## Intel Wi-Fi Driver Hangs

Some Intel Wi-Fi cards using `iwlwifi` can hang while entering suspend. The
symptom is:

- the display goes black
- keyboard and mouse lights turn off
- fans or PC power remain on
- WOL packets are sent but do not wake the PC
- the previous boot log ends near `PM: suspend entry (deep)` with no resume log

That means the machine did not finish entering a clean sleep state. WOL cannot
recover that state.

Check whether the system uses `iwlwifi`:

```bash
lspci -nnk | grep -A4 -i 'network controller'
lsmod | grep -E 'iwlwifi|iwlmvm|mac80211'
```

First confirm Ethernet is the primary route so unloading Wi-Fi will not cut off
remote access:

```bash
ip route show default
nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device
```

Then test unload/reload while physically present:

```bash
sudo ip link set <WIFI_INTERFACE> down
sudo modprobe -r iwlwifi
sudo modprobe iwlwifi
sudo ip link set <WIFI_INTERFACE> up
```

If `modprobe -r iwlwifi` fails with a message like `rmmod: ERROR: missing
module name`, inspect `/etc/modprobe.d/iwlwifi.conf`. Some systems ship a
fragile `remove iwlwifi` rule that recursively calls itself or calls `rmmod`
with no module arguments. Back it up before editing.

If unload/reload works and suspend hangs only while `iwlwifi` is loaded, add a
reversible systemd sleep hook that unloads Wi-Fi before suspend and reloads it
after resume:

```sh
#!/bin/sh
set -u

IFACE=<WIFI_INTERFACE>
TAG=iwlwifi-suspend-workaround

case "$1/$2" in
  pre/*)
    if lsmod | grep -q '^iwlwifi'; then
      logger -t "$TAG" "Taking $IFACE down and unloading iwlwifi before suspend"
      /sbin/ip link set "$IFACE" down 2>/dev/null || true
      /sbin/modprobe -r iwlwifi || exit 1
    fi
    ;;
  post/*)
    logger -t "$TAG" "Reloading iwlwifi after resume"
    /sbin/modprobe iwlwifi 2>/dev/null || true
    /sbin/ip link set "$IFACE" up 2>/dev/null || true
    ;;
esac
```

Install it as a root-owned executable file under `/etc/systemd/system-sleep/`.
Test the `pre` and `post` paths manually before trying another real suspend.

## Safe Isolation Order

Use the least disruptive checks first:

1. Confirm `systemctl suspend` works locally.
2. Confirm keyboard or power-button wake works locally.
3. Confirm router WOL wakes from suspend.
4. Confirm router WOL wakes from shutdown.
5. Only then add the phone shortcut and idle suspend.

Avoid changing NetworkManager profiles, Wi-Fi credentials, router firewall
rules, or boot settings while testing suspend unless you have a local recovery
path.
