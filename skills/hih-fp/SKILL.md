---
name: hih-fp
description: Solve problems with First Principles + Musk's 5 steps. Break assumptions and rebuild from fundamentals.
user_invocable: true
---

# /hih-fp

Solve the problem using First Principles thinking + Musk's 5-step engineering process.
Use `~/.claude/rules/deep-fp.md` as the thinking framework.

## Behavior when invoked

### 1. Receive the problem
When the user presents a problem/task, do not solve it immediately.

### 2. First Principles analysis (required output)
```
## First Principles analysis

### List assumptions
- Assumption 1: ...
- Assumption 2: ...
- Assumption 3: ...

### Verify assumptions
- Assumption 1: ✅ true / ❌ no evidence / ⚠️ partial
- Assumption 2: ...

### Fundamental truths
- Truth 1: (a fact that can no longer be decomposed)
- Truth 2: ...
```

### 3. Apply the 5-step process (required output)
```
### Step 1: Question the requirements
- Who created this requirement?
- Is it really necessary? Why?

### Step 2: Delete
- What parts/processes can be removed?
- "Can this be solved without it?"

### Step 3: Simplify
- How can what remains be simplified?

### Step 4: Accelerate
- How can the cycle time be reduced?

### Step 5: Automate
- How can the repetitive parts be automated?
```

### 4. Rebuild
Design the solution based on the fundamental truths + the results of the 5 steps.

### 5. Verify
Confirm via prototype/test. If it fails, re-examine the assumptions.

## Triggers
- "Think about it from first principles"
- "/deep-fp"
- "Why are we doing it this way?"
- When you have doubts about the existing approach
- Cost/performance/complexity problems
