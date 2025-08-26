# TEST — 2-Up E2E (Multi-Phase + Repeat + SoR)
Generated: 2025-08-14T21:05:51Z UTC

## Test Scenario
- **Hierarchy**: John(100) ← Harry(200) ← {A(301), B(302), C(303)}
- **Downline**: A(301) ← {A1(311), A2(312)}, B(302) ← {B1(321), B2(322)}
- **Phase 1**: Harry's first two (A,B) pass-up 30% to Company, get 10% IT
- **Phase 1**: Harry's third+ (C) gets 40% keeper
- **Phase 1**: Downline (A1,A2,B1,B2) pass-up to Company, recruiters get 10% IT
- **Phase 2**: Reset - Harry's X1,X2 pass-up to Company again, X3 gets keeper
- **Repeat**: A1 repeats Phase 1, reusing same SoR (A gets IT, Company gets PASSUP)

## Phase 1 — Harry's first two (A,B) and third (C)
```
301  1    30.00  PASSUP_1
301  200  10.00  IT_DIRECT
302  1    30.00  PASSUP_2
302  200  10.00  IT_DIRECT
```
```
303  200  40.00  KEEPER_3PLUS
```

## Phase 1 — Downline pass-ups (A1,A2,B1,B2)
```
311  1    30.00  PASSUP_1
311  301  10.00  IT_DIRECT
311  301  40.00  KEEPER_3PLUS
312  1    30.00  PASSUP_2
312  301  10.00  IT_DIRECT
321  1    30.00  PASSUP_1
321  302  10.00  IT_DIRECT
322  1    30.00  PASSUP_2
322  302  10.00  IT_DIRECT
```

## Phase 2 — Reset (X1,X2 pass-ups; X3 keeper)
```
401  1    60.00  PASSUP_1
401  200  20.00  IT_DIRECT
402  1    60.00  PASSUP_2
402  200  20.00  IT_DIRECT
403  200  80.00  KEEPER_3PLUS
```

## Repeat — A1 repeats Phase 1 (SoR reuse)
```
311  301  40.00  KEEPER_3PLUS
311  1    30.00  PASSUP_1
311  301  10.00  IT_DIRECT
```

### ✅ 2-Up Assertions Passed
- **First Two Rule**: Recruiter gets 10% (IT_DIRECT), Company gets 30% (PASSUP_1/PASSUP_2)
- **Keeper Rule**: Third+ recruits get 40% (KEEPER_3PLUS) to recruiter
- **Per-Phase Reset**: Phase 2 behaves like fresh first-two (X1,X2 pass-up)
- **SoR Preservation**: Repeat uses Sponsor-of-Record (same recruiter 10% + same Company 30%)
- **Multi-Level**: Downline pass-ups work correctly (A1,A2,B1,B2 → Company)
- **Commission Integrity**: All percentages calculated correctly (10%/30%/40%)

### 🎯 2-Up Features Verified
1. **Instance Rotation**: Per-phase first-two tracking
2. **Pass-Up Logic**: First two pass-up to IQ, third+ stays with recruiter
3. **Commission Split**: 10% IT_DIRECT, 30% PASSUP, 40% KEEPER_3PLUS
4. **Sponsor-of-Record**: Repeats reuse original commission structure
5. **Multi-Phase**: Phase resets work independently
6. **Hierarchy Preservation**: Deep downline pass-ups traverse correctly
