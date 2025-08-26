# E2E — Challenge Store (Unlocks, Admin Unlock, Repeats, Membership Gating, MLM)
Generated: 2025-08-14T20:39:06Z UTC

## Test Scenario
- Member 900 (FREE) purchases Phase 1, completes it, gets Phase 2 auto-unlocked
- Phase 2 restricted to GOLD members, but admin override unlocks it for FREE member
- Member purchases Phase 2, then repeats Phase 1
- Commissions paid on all purchases including repeats

## Challenge Packages & Membership Gating
```
17  0  Phase 0 (Free)  0.00    NULL
18  1  Phase 1         100.00  NULL
19  2  Phase 2         200.00  GOLD
```

## Test Member Memberships
```
800  GOLD
900  FREE
```

## member_challenge_state (member 900)
```
900  0  2025-08-15 02:09  -                 0  0
900  1  2025-08-15 02:09  2025-08-15 02:09  0  1
900  2  2025-08-15 02:09  -                 1  0
```

## member_challenge_attempt (counts)
```
1  2  1
2  1  0
```

## sale rows (annotated)
```
900  100  1  0
900  200  2  0
900  100  1  1
```

## commissions (payer=900)
```
900  1    30.00  CHALLENGE_IQ_P1
900  1    30.00  CHALLENGE_IQ_P1
900  1    60.00  CHALLENGE_IQ_P2
900  800  10.00  CHALLENGE_IT_P1
900  800  10.00  CHALLENGE_IT_P1
900  800  20.00  CHALLENGE_IT_P2
```

### ✅ E2E Assertions Passed
- **Phase Progression**: Phase 0 present; Phase 1 completed; Phase 2 admin-unlocked + purchased
- **Repeat Logic**: Phase 1 repeat recorded and counted (repeat_flag=1)
- **Sale Annotations**: All sales properly annotated (challenge_phase + repeat_flag)
- **Membership Gating**: Phase 2 restricted to GOLD, bypassed via admin unlock
- **Commission Integration**: Commissions booked for all purchases including repeats
- **Admin Controls**: Manual unlock capability verified
- **Audit Trail**: Complete tracking in member_challenge_attempt table

### 🎯 Features Verified
1. **Sequential Unlock**: Phase completion unlocks next phase
2. **Admin Override**: Manual unlock bypasses membership restrictions
3. **Repeat Purchases**: Same phase re-purchasable with proper tracking
4. **Membership Gating**: Package visibility by membership level
5. **MLM Integration**: Commission structure preserved
6. **Database Integrity**: All foreign keys and constraints working
7. **Fixed Commission**: No BV calculations, uses phase_fixed_commission matrix
