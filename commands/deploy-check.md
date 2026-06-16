---
name: deploy-check
description: 배포 전 체크리스트 — 빌드, 테스트, 타입체크, 보안 스캔 종합 검증
user-invocable: true
---

# 배포 전 체크리스트

현재 프로젝트의 배포 준비 상태를 종합 검증한다.

## 검증 항목

### 1. 빌드
- Python: `python3 -m py_compile` (모든 .py 파일)
- Next.js: `npm run build`
- TypeScript: `npx tsc --noEmit`

### 2. 테스트
- pytest / npm test 실행
- 커버리지 확인 (가능한 경우)

### 3. 타입 체크 (TS 프로젝트)
- `npx tsc --noEmit --strict`
- ESLint: `npx eslint . --max-warnings=0`

### 4. 보안
- 하드코딩 시크릿 스캔
- `.env.example` 존재 여부
- `.gitignore`에 민감 파일 포함 여부

### 5. Git 상태
- 미커밋 파일 없는지
- 메인 브랜치와 동기화 상태

## 결과 형식
```
## 배포 체크리스트 — {프로젝트명}

| 항목 | 상태 | 비고 |
|------|------|------|
| 빌드 | ✅/❌ | ... |
| 테스트 | ✅/❌ | 통과: N, 실패: N |
| 타입체크 | ✅/❌ | 에러: N |
| 보안 | ✅/❌ | 경고: N |
| Git | ✅/❌ | ... |

### 결론: 배포 가능 / 배포 불가 (사유)
```
