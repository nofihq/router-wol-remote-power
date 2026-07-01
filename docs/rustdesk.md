# RustDesk Notes

RustDesk handles the interactive desktop session. The WOL/power API only wakes,
suspends, or shuts down the machine.

Typical unattended setup:

1. Install RustDesk on the workstation and phone.
2. Start or enable the RustDesk service on the workstation.
3. In RustDesk security settings, set a permanent password for unattended
   access.
4. Save the workstation ID in the phone client.
5. After waking the workstation, wait for Tailscale and RustDesk to reconnect.

Command-line support varies by platform/build, but RustDesk documents client
parameters such as `--password` for setting a permanent password and `--get-id`
for retrieving the ID. Prefer the official GUI settings unless you are building
an installer for your own machines.

Do not commit RustDesk IDs, passwords, relay credentials, or screenshots showing
private details.

If you automate entering an ID/password on the phone, store those values only in
the phone's local Shortcuts/RustDesk configuration, not in this repository.
