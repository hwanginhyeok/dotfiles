---
name: hih-ontology
description: Structure a problem with ontological thinking. Define entities/properties/relations/constraints/hierarchy first, then solve.
user_invocable: true
---

# /hih-ontology

Decompose the problem ontologically, then solve it.
Use `~/.claude/rules/deep-ontology.md` as the thinking framework.

## Behavior when run

### 1. Receive the problem
When the user presents a problem/task, do not jump straight to coding.

### 2. Ontology analysis (required output)
```
## 온톨로지 분석

### 개체 (Entities)
- 개체1: 설명
- 개체2: 설명

### 속성 (Properties)
- 개체1.속성: 타입, 설명
- 개체2.속성: 타입, 설명

### 관계 (Relations)
- 개체1 → 개체2: 관계 유형 (is-a / has-a / causes / depends-on)

### 제약조건 (Constraints)
- 규칙1: ...
- 규칙2: ...

### 계층 (Hierarchy)
- 상위 범주 > 하위 범주
```

### 3. Structure validation
- "Is any entity missing?"
- "Are any relations missing or circular?"
- "Do any constraints conflict?"

### 4. Implementation
Proceed with code/design based on the ontology structure.

## Triggers
- "이 문제 온톨로지로 분석해줘"
- "/deep-ontology"
- Complex domain-modeling problems
- Designs with complex relations between entities
