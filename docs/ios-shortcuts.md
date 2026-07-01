# iOS Shortcuts

Each shortcut uses one **Get Contents of URL** action.

## PC ON

Use this when the PC is asleep or fully shut down.

```text
URL: http://<ROUTER_TAILSCALE_IP>:8080/wake
Method: GET
Header key: Authorization
Header value: Bearer <TOKEN>
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
Header value: Bearer <TOKEN>
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
Header value: Bearer <TOKEN>
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
Header value: Bearer <TOKEN>
```

Expected response:

```text
ON
```

If the request fails or times out, the PC is probably asleep, shut down, or not
yet back on Tailscale.
