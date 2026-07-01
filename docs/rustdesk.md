# RustDesk Notes

RustDesk handles the interactive desktop session. The WOL/power API only wakes,
suspends, or shuts down the machine.

## What To Install

Install RustDesk on:

- the PC you want to control
- the iPhone you will control it from

On Linux, use the RustDesk package for your distribution when possible. For
Ubuntu/Debian-style systems, that usually means downloading the `.deb` package
from RustDesk and installing it with:

```bash
sudo apt install -fy ./rustdesk-<version>.deb
```

On iPhone, install RustDesk from the App Store.

Official client docs:

```text
https://rustdesk.com/docs/en/client/
```

## PC Setup

On the PC:

1. Install RustDesk on the PC.
2. Open RustDesk.
3. Start or enable the RustDesk service if the app asks for it.
4. In RustDesk security settings, set a permanent password for unattended
   access.
5. Copy the RustDesk ID shown on the PC.
6. Test from the phone while you are still at home.

The exact menu names can vary by RustDesk version, but the setting you need is
the permanent/unattended password in the client security settings.

If you use Linux with Wayland and remote control is unreliable, test an X11
session. RustDesk's Linux documentation notes Wayland and login-screen
limitations.

## iPhone Setup

On the iPhone:

1. Install RustDesk.
2. Add the PC's RustDesk ID.
3. Save the permanent password in the RustDesk app if you are comfortable doing
   that.
4. Wake the PC with the `PC ON` Shortcut.
5. Wait for Tailscale and RustDesk to reconnect.
6. Open the saved RustDesk connection.

Command-line support varies by platform/build, but RustDesk documents client
parameters such as `--password` for setting a permanent password and `--get-id`
for retrieving the ID. Prefer the official GUI settings unless you are building
an installer for your own machines.

Do not commit RustDesk IDs, passwords, relay credentials, or screenshots showing
private details.

If you automate entering an ID/password on the phone, store those values only in
the phone's local Shortcuts/RustDesk configuration, not in this repository.

## What Not To Store In This Repo

- RustDesk ID
- RustDesk permanent password
- RustDesk relay credentials
- screenshots showing private IDs or IPs
