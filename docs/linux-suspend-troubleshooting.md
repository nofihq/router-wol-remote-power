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

For NVIDIA systems, verify that the running kernel has a matching driver before
every first suspend test after a kernel upgrade:

```bash
uname -r
modinfo nvidia
nvidia-smi
lspci -nnk | grep -A4 -i 'vga\|3d controller'
```

If `modinfo` reports that `nvidia` is missing for the running kernel, do not
suspend yet. Install the matching kernel module with the distribution's driver
tool, then reboot. On Ubuntu, start with:

```bash
sudo ubuntu-drivers install
```

The exact package name and NVIDIA branch vary by Ubuntu release and GPU. A
kernel can boot using a fallback renderer even though its NVIDIA module is
missing; in that state suspend may resume to a powered-on black screen. Add
`SUSPEND_REQUIRE_LOADED_MODULES=nvidia` to `pc.env` after the NVIDIA driver is
working so the installed helper and sleep hook reject that unsafe state.

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
recover that state. Treat it as a failed suspend attempt, not as the normal
`sleep -> on` state described in the shortcut docs.

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

Install it as a root-owned executable file under the systemd sleep-script
directory used by the target machine. Common locations are
`/etc/systemd/system-sleep/` and `/usr/lib/systemd/system-sleep/`.

Check the path before relying on the hook:

```bash
strings /usr/lib/systemd/systemd-sleep | grep system-sleep
```

Some distributions or systemd builds only execute `/usr/lib/systemd/system-sleep`.
If the hook works when run manually but never logs during real suspend, install
the hook in the directory printed by that command. Test the `pre` and `post`
paths manually before trying another real suspend.

The repository installer deploys `pc/helpers/phone-wol-power-system-sleep` to
`/usr/lib/systemd/system-sleep/phone-wol-power`. Configure that hook through
`/etc/phone-wol-power/pc.env`:

```text
SUSPEND_PRE_DOWN_IFACE=<WIFI_INTERFACE>
SUSPEND_PRE_UNLOAD_MODULES=iwlwifi
```

With those values set, the systemd hook brings the Wi-Fi interface down and
unloads `iwlwifi` during systemd's real pre-sleep phase. It reloads the module
and restores the interface during the post-resume phase. Do not duplicate this
work inside the command that calls `systemctl suspend`: systemctl can return
before sleep begins, causing an early reload to race the pre-sleep hook.

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
