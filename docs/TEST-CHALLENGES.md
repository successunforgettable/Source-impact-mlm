# TEST — Challenge Store E2E (Unlocks, Repeats, Fixed %, MLM Integration)
Generated: 2025-08-14T20:27:11Z UTC

## member_challenge_state (member 900)
```
900  0  2025-08-15 01:57  -                 0
900  1  2025-08-15 01:57  2025-08-15 01:57  1
900  2  2025-08-15 01:57  -                 0
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

### Assertions Passed ✅
- Phase 0 present; Phase 1 completed; Phase 2 unlocked
- Repeat of Phase 1 recorded and counted
- Sales annotated with challenge_phase + repeat_flag
- Commissions booked for all purchases
- Challenge purchase flow working end-to-end
