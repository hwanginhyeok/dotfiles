---
name: hih-vnc
description: Check VNC connection status + provide access URL. For dev verification, connect directly to localhost inside VNC
---

# /hih-vnc skill

Checks VNC service status and provides the access URL.

## Behavior on execution

### 1. Check service status
```bash
systemctl --user is-active vnc-server 2>/dev/null
systemctl --user is-active fluxbox 2>/dev/null
systemctl --user is-active novnc 2>/dev/null
tailscale status --self 2>/dev/null | head -1
```

### 2. Verify connectivity
```bash
curl -sI http://127.0.0.1:6080/ | head -3
```
- 200 OK → normal
- Connection failure → **noVNC is not a systemd service. Manual restart required**:
```bash
nohup websockify --web /usr/share/novnc 6080 localhost:5901 > /tmp/novnc.log 2>&1 &
sleep 2
curl -s http://127.0.0.1:6080/ | grep -i novnc | head -1
```

### 3. Check Funnel status (required!)
```bash
tailscale funnel status 2>/dev/null
```
- Confirm `(Funnel on)` is shown on port 443
- **If it shows `(tailnet only)`, external access is unavailable** → enable Funnel:
```bash
tailscale funnel --bg --https 443 http://127.0.0.1:6080
```
- After confirming Funnel on, provide the URL

> **Note**: When the PC restarts or Tailscale restarts, Funnel may turn off. Always verify each time.

### 4. Output the access URL
```
## VNC access info

- **URL**: https://desktop-plq9e0i.tailec5aa6.ts.net/vnc.html
- **Password**: `${VNC_PASSWORD}` (set via env var or `.env` file)
- **Status**: ✅ normal (or ❌ + recovery attempt result)
```
> ⚠️ Always include `/vnc.html`. The root (/) may show a Directory Listing.

### 5. Dev server verification guide
After connecting via VNC, enter directly in the browser:

| Project | Access URL inside VNC |
|----------|-------------------|
| 인성이 (Next.js) | `http://localhost:3002` |
| 인성이 (API) | `http://localhost:8001` |
| 주식부자 (API) | `http://localhost:8200` |

## Troubleshooting

### When "Directory Listing" appears on VNC access
→ Check the index.html symlink:
```bash
ls -la /usr/share/novnc/index.html
# If missing: echo '0055' | sudo -S ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html
```

### When the dev server UI is broken (CSS/JS 404)
→ The Next.js dev server has been running too long and the bundle version is stale. Kill the process and restart:
```bash
ps aux | grep "next dev" | grep -v grep
kill <PID>
cd <project>/apps/web && npx next dev -p <port> &
```

### Manual noVNC restart (most common case)
noVNC is not a systemd service — it dies on reboot/crash. Run it directly:
```bash
nohup websockify --web /usr/share/novnc 6080 localhost:5901 > /tmp/novnc.log 2>&1 &
```

### Restart the VNC server (Xtigervnc) (when restarting noVNC doesn't help)
```bash
systemctl --user restart vnc-server fluxbox
# Then restart noVNC as well
nohup websockify --web /usr/share/novnc 6080 localhost:5901 > /tmp/novnc.log 2>&1 &
```
