# iOS Shortcuts

Each shortcut uses one **Get Contents of URL** action.

## State Rules

The router wake API and the PC power API are different services:

| PC state | What works | What times out |
| --- | --- | --- |
| On | `PC SUSPEND`, `PC OFF`, `PC STATUS` | Nothing, if the PC API is healthy. |
| Asleep | `PC ON` | `PC OFF`, `PC SUSPEND`, `PC STATUS` |
| Fully off | `PC ON` | `PC OFF`, `PC SUSPEND`, `PC STATUS` |

`PC OFF` only works while the active operating system is awake because the
shutdown endpoint runs on the PC.

If a suspend attempt leaves the monitor black while fans or PC power stay on,
do not treat that as normal sleep. The PC is wedged during suspend entry, so
the PC API cannot answer and WOL may not wake it. Fix suspend first. Linux users
can see [Linux Suspend Troubleshooting](linux-suspend-troubleshooting.md), and
Windows users can see [Windows Setup](windows-setup.md#troubleshooting).

On a dual-boot PC, Windows and Linux usually have different Tailscale IPs. Use
the optional router dispatcher below for one shortcut set, or create one set
per OS. The router-based `PC ON` shortcut remains unchanged.

Supported direct interactions:

- off -> on
- sleep -> on
- on -> sleep
- on -> off
- on -> status

Not supported directly:

- sleep -> off
- off -> sleep
- off -> status
- sleep -> status

## PC ON

Use this when the PC is asleep or fully shut down.

```text
URL: http://<ROUTER_TAILSCALE_IP>:8080/wake
Method: GET
Header key: Authorization
Header value: Bearer <ROUTER_TOKEN>
```

Expected response:

```text
Wake packet sent
```

## PC SUSPEND

Use this when the PC is awake and you want to keep your session state.

```text
URL: http://<PC_TAILSCALE_IP>:8081/suspend
Method: GET
Header key: Authorization
Header value: Bearer <PC_TOKEN>
```

Expected response:

```text
Suspending...
```

## PC OFF

Use this when you are done for a longer period.

```text
URL: http://<PC_TAILSCALE_IP>:8081/shutdown
Method: GET
Header key: Authorization
Header value: Bearer <PC_TOKEN>
```

Expected response:

```text
Shutting down...
```

## PC STATUS

Optional convenience check.

```text
URL: http://<PC_TAILSCALE_IP>:8081/status
Method: GET
Header key: Authorization
Header value: Bearer <PC_TOKEN>
```

Expected response:

```text
ON
```

If the request fails or times out, the PC is probably asleep, shut down, or not
yet back on Tailscale.

## Dual-Boot Automatic Routing

The router can try the Linux and Windows PC API addresses and forward to the
one that is currently awake. First configure `PC_API_TARGETS` and
`PC_AUTH_TOKEN_FILE` on the router as described in
[End-To-End Setup](setup.md#optional-dual-boot-pc-api-dispatcher).

Then use these URLs instead of the direct PC URLs:

```text
PC SUSPEND: http://<ROUTER_TAILSCALE_IP>:8080/suspend
PC OFF:     http://<ROUTER_TAILSCALE_IP>:8080/shutdown
PC STATUS:  http://<ROUTER_TAILSCALE_IP>:8080/status
Header:     Authorization: Bearer <PC_TOKEN>
```

The router tests each configured PC API with a short timeout and uses the first
one that answers. Use the same `<PC_TOKEN>` in the Linux API, Windows API, phone
shortcuts, and router-side PC token file.

`PC ON` remains:

```text
URL: http://<ROUTER_TAILSCALE_IP>:8080/wake
Header: Authorization: Bearer <ROUTER_TOKEN>
```

Wake from sleep resumes whichever OS was sleeping. Wake from full shutdown
boots the OS selected by firmware/your bootloader default; the dispatcher does
not select an operating system at boot.
