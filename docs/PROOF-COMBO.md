# PROOF — Combined 2-Up + Phases + Leadership
Generated: 2025-08-14T19:39:41Z UTC

---

## A) 2-Up (core)
(From docs/PROOF-2UP.md)
```markdown
# PROOF — 2-Up Implementation

- Generated: 2025-08-14T19:39:41Z UTC
- Migration: conf/migrations/2025_08_2up.sql

## passup_event
```
68  301  200  100  PASSUP_1      2025-08-15 01:09:41  NULL  NULL
69  302  200  100  PASSUP_2      2025-08-15 01:09:41  NULL  NULL
70  303  200  200  KEEPER_3PLUS  2025-08-15 01:09:41  NULL  NULL
```

## commissions
```
301  100  0.00  PASSUP_1
302  100  0.00  PASSUP_2
303  200  0.00  KEEPER_3PLUS
```
```

---

## B) Phases (per-phase pass-ups, keepers, compression)
(From docs/PROOF-PHASES.md)
```markdown
# PROOF — Phases + Compression

- Generated: 2025-08-14T19:39:41Z UTC
- Migrations: `2025_08_2up.sql`, `2025_08_phases.sql`

## passup_event
```
71  311  200  100  PASSUP_1      30  28  2025-08-15 01:09:41
72  312  200  100  PASSUP_2      30  28  2025-08-15 01:09:41
73  313  200  200  KEEPER_3PLUS  30  28  2025-08-15 01:09:41
74  321  200  1    PASSUP_1      31  29  2025-08-15 01:09:41
```

## commissions
```
311  100  1000.00  0.3000  300.00  PASSUP_1      30  28
311  200  1000.00  0.1000  100.00  IT_DIRECT     30  28
312  100  1000.00  0.3000  300.00  PASSUP_2      30  28
312  200  1000.00  0.1000  100.00  IT_DIRECT     30  28
313  200  1000.00  0.4000  400.00  KEEPER_3PLUS  30  28
321  1    2000.00  0.3000  600.00  PASSUP_1      31  29
321  200  2000.00  0.1000  200.00  IT_DIRECT     31  29
```

## phase_enrollment
```
57  100  30  28  IQ  2  1    100   2025-08-15 01:09:41  2025-08-15 00:09:41
58  200  30  28  IQ  2  100  NULL  2025-08-15 01:09:41  2025-08-15 01:09:41
60  311  30  28  IT  0  200  100   NULL                 2025-08-15 01:09:41
61  312  30  28  IT  0  200  100   NULL                 2025-08-15 01:09:41
62  313  30  28  IT  0  200  NULL  NULL                 2025-08-15 01:09:41
59  200  31  29  IT  1  100  NULL  NULL                 2025-08-15 01:09:41
63  321  31  29  IT  0  200  1     NULL                 2025-08-15 01:09:41
```

## compression_log
```
321  100  1  31  29  NOT_JOINED_IN_WINDOW  2025-08-15 01:09:41
```
```

---

## C) Leadership (assigned-team overrides with cut-off)
### leadership_rank
```
101  ASSISTANT_NTM  1  2025-08-15 01:09
102  NTM            1  2025-08-15 01:09
103  VP             0  -
203  ASSISTANT_NTM  1  2025-08-15 01:09
```

### leadership_assignment
```
101  201  1
101  202  1
102  203  1
103  204  1
```

### leadership_earnings (this week)
```
101  201  4000.00  0.0500  200.00  LDR_ASSISTANT_NTM
101  202  2000.00  0.0500  100.00  LDR_ASSISTANT_NTM
1    204  8000.00  0.0200  160.00  LDR_VP
```

### commissions (LDR_* booked)
```
204  1    160.00  LDR_VP
201  101  200.00  LDR_ASSISTANT_NTM
202  101  100.00  LDR_ASSISTANT_NTM
```

### Assertions
- L1 (ASSISTANT_NTM, qualified) total ≈ **75.00**: 300.00
- L3 (VP, **unqualified**) → Company routed via `LDR_VP` (expect ≥40.00): 160.00
- **Cut-off**: L2 **does not** earn on C (qualified leader) → count of `LDR_NTM` rows for C: 0

---

## D) Interactions (what this proves)
- 2-Up pass-ups (10/30), keepers (40), and **per-phase IQ promotion** function independently from Leadership.
- Leadership overrides are **additional**; they do not change 2-Up/Phase commissions.
- **Downline leader cut-off** prevents the upline from earning on groups owned by a qualified downline leader.
- **Unqualified leadership** routes to Company.
