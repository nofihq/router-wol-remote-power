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
