# PM 지시 — [작업명]

> 결정일: YYYY-MM-DD / 출처: 사용자 메시지 또는 PM 자체 판단

## 메타

| 항목 | 값 |
|------|-----|
| **영향 파일** | scripts/X.py (신규) / config/Y.yaml (수정) / docs/Z.md (신규) |
| **의존성** | (없음 / BAS-NN 선행) |
| **병렬 안전성** | ✅ 독립 / ⚠️ 부분 충돌 / ❌ 순차 필수 |
| **위임 모드** | single-session / **agent-parallel** / session-fanout |
| **예상 시간** | X-Y분 (병렬 시 단축 예상치) |
| **머지 책임** | PM (기본) / 세션 자체 |
| **검증 절차** | import smoke / dry-run / git diff / 별도 fixture |

## 작업 본문

[작업 내용]

### Step N
[하위 단계]

## 병렬 분기 (위임 모드 = agent-parallel 시)

다음 작업들은 **파일 겹침 없음 + 의존 없음** → 위임받은 세션이 Agent 하위 분기로 동시 처리:

| Track | 작업 | 영향 파일 | 단독 시간 |
|-------|------|---------|---------|
| A | [작업 A] | scripts/A.py (신규) | 30분 |
| B | [작업 B] | scripts/B.py (신규) | 25분 |
| C | [작업 C] | docs/C.md (신규) | 20분 |

**분기 방법** (위임받은 세션이 실행):
```
1. 메인 세션은 본인 작업 + 오케스트레이션
2. 독립 트랙은 Agent tool로 worktree isolation 분기:
   - subagent_type: general-purpose
   - isolation: "worktree"
   - 각 Agent에 독립 작업 prompt 전달
3. 모든 Agent 완료 후 메인 세션이 결과 취합
4. main 브랜치로 머지 (rebase 또는 cherry-pick)
5. 충돌 시 사용자 보고
```

**병렬 금지 영역** (메인 세션이 직접):
- PREPARED_TASK.md / FINISHED_TASK.md / CURRENT_TASK.md (머지 충돌 회피)
- handoff*.md (한 곳에서만 작성)
- 의존성 있는 작업 (BAS-79 → BAS-80 같은)

## 룰 (전 작업 공통)

- git push 금지 (로컬 커밋만)
- 작업 단위마다 커밋
- 의존성 추가 시 requirements.txt + 별도 커밋
- .env / DDL 변경 금지
- 에러 3회 시 스킵 + 기록
- 중간 보고 금지 — 모든 트랙 완료 후 한 번에

## 보고

`docs/briefs/handoff_YYYYMMDD_[작업명].md`:
- Track별 결과 (커밋 / 검증 / 한계)
- 머지 충돌 발생 시 처리 내역
- 다음 세션 인계 사항

작업 끝나면 idle 유지. 사용자 다음 결정 대기.

---

## 사용 가이드 (PM이 이 템플릿 작성 시)

1. 작업 N개로 분해
2. 각 작업의 영향 파일 / 의존성 명확히
3. 겹침 매트릭스로 병렬 안전성 판정
4. 위임 모드 결정:
   - `single-session`: 작업 1개 또는 의존성 강함
   - `agent-parallel`: 독립 작업 2개+ (B3 패턴, 권장)
   - `session-fanout`: 장기 작업 + 사람도 시각 모니터링 필요
5. 세션에 send-keys로 지시 파일 경로 전달
6. 다음 wakeup으로 진행도 모니터링
