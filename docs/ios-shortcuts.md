# iOS Shortcuts

Each shortcut uses one **Get Contents of URL** action.

## State Rules

The router wake API and the PC power API are different services:

| PC state | What works | What times out |
| --- | --- | --- |
| On | `PC SUSPEND`, `PC OFF`, `PC STATUS` | Nothing, if the PC API is healthy. |
| Asleep | `PC ON` | `PC OFF`, `PC SUSPEND`, `PC STATUS` |
| Fully off | `PC ON` | `PC OFF`, `PC SUSPEND`, `PC STATUS` |

`PC OFF` only works while Linux is awake because the shutdown endpoint runs on
the PC.

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
