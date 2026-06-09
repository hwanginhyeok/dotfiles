---
name: hih-vnc
description: VNC 연결 상태 확인 + 접속 URL 제공. dev 확인은 VNC 안에서 localhost 직접 접속
---

# /hih-vnc 스킬

VNC 서비스 상태를 확인하고 접속 URL을 제공한다.

## 실행 시 동작

### 1. 서비스 상태 확인
```bash
systemctl --user is-active vnc-server 2>/dev/null
systemctl --user is-active fluxbox 2>/dev/null
systemctl --user is-active novnc 2>/dev/null
tailscale status --self 2>/dev/null | head -1
```

### 2. 연결 가능성 검증
```bash
curl -sI http://127.0.0.1:6080/ | head -3
```
- 200 OK → 정상
- 연결 실패 → **noVNC는 systemd 서비스가 아님. 수동 재시작 필요**:
```bash
nohup websockify --web /usr/share/novnc 6080 localhost:5901 > /tmp/novnc.log 2>&1 &
sleep 2
curl -s http://127.0.0.1:6080/ | grep -i novnc | head -1
```

### 3. Funnel 상태 확인 (필수!)
```bash
tailscale funnel status 2>/dev/null
```
- 443 포트에 `(Funnel on)` 표시 확인
- **`(tailnet only)`로 되어 있으면 외부 접근 불가** → Funnel 활성화:
```bash
tailscale funnel --bg --https 443 http://127.0.0.1:6080
```
- Funnel on 확인 후 URL 안내

> **주의**: PC 재시작/Tailscale 재시작 시 Funnel이 꺼질 수 있다. 매번 확인 필수.

### 4. 접속 URL 출력
```
## VNC 접속 정보

- **URL**: https://desktop-plq9e0i.tailec5aa6.ts.net/vnc.html
- **비밀번호**: suno
- **상태**: ✅ 정상 (또는 ❌ + 복구 시도 결과)
```
> ⚠️ `/vnc.html` 반드시 포함. 루트(/)는 Directory Listing 뜰 수 있음.

### 5. dev 서버 확인 안내
VNC 접속 후 브라우저에서 직접 입력:

| 프로젝트 | VNC 안에서 접속 URL |
|----------|-------------------|
| 인성이 (Next.js) | `http://localhost:3002` |
| 인성이 (API) | `http://localhost:8001` |
| 주식부자 (API) | `http://localhost:8200` |

## 트러블슈팅

### VNC 접속 시 "Directory Listing" 나올 때
→ index.html 심링크 확인:
```bash
ls -la /usr/share/novnc/index.html
# 없으면: echo '0055' | sudo -S ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html
```

### dev 서버 UI 깨질 때 (CSS/JS 404)
→ Next.js dev 서버가 오래 돌아서 번들 버전 stale. 프로세스 죽이고 재시작:
```bash
ps aux | grep "next dev" | grep -v grep
kill <PID>
cd <프로젝트>/apps/web && npx next dev -p <포트> &
```

### noVNC 수동 재시작 (가장 흔한 케이스)
noVNC는 systemd 서비스 아님 — 재부팅/크래시 시 죽음. 직접 실행:
```bash
nohup websockify --web /usr/share/novnc 6080 localhost:5901 > /tmp/novnc.log 2>&1 &
```

### VNC 서버(Xtigervnc) 재시작 (noVNC 재시작해도 안될 때)
```bash
systemctl --user restart vnc-server fluxbox
# 이후 noVNC도 재시작
nohup websockify --web /usr/share/novnc 6080 localhost:5901 > /tmp/novnc.log 2>&1 &
```
