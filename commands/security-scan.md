---
name: security-scan
description: 전 프로젝트 보안 취약점 스캔 (OWASP, 시크릿 노출, 인젝션)
user-invocable: true
---

# 전체 보안 스캔

## 대상 프로젝트
- `~/stock`
- `~/insung_blog`
- `~/my-politics-stats`
- `~/physical_AI_rs500`

## 스캔 항목

### 1. 시크릿 노출
- `.env` 파일이 `.gitignore`에 포함되어 있는지
- 코드에 하드코딩된 API 키, 비밀번호, 토큰
- git 히스토리에 시크릿 커밋 여부: `git log --all -p | grep -i "api_key\|secret\|password"`

### 2. 인젝션 취약점
- SQL: f-string/format으로 쿼리 조합
- 커맨드: subprocess에 shell=True + 사용자 입력
- XSS: innerHTML, dangerouslySetInnerHTML

### 3. 인증/인가
- API 라우트에 인증 미들웨어 누락
- CORS 설정 과도하게 열려 있는지

### 4. 의존성
- `pip list --outdated` 또는 `npm audit`

## 실행
각 프로젝트에 대해 security-auditor 에이전트를 사용하여 스캔.

## 결과
프로젝트별 보안 리포트를 종합하여 출력.
