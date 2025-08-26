# PROOF: Repeat Purchases (No Extra MLM Payout)

## Phase 1 — Harry repeat


```sql
SELECT saleid,memberid,challenge_phase,repeat_flag,amount FROM sale WHERE memberid=2 AND challenge_phase=1 ORDER BY saleid;
```

101	2	1	0	100
150	2	1	1	100

```sql
SELECT order_id,receiver_user_id,percent,amount,reason_code FROM commissions WHERE phase_id=1 AND order_id=150;
```


## Phase 2 — Ayesha repeat


```sql
SELECT saleid,memberid,challenge_phase,repeat_flag,amount FROM sale WHERE memberid=3 AND challenge_phase=2 ORDER BY saleid;
```

202	3	2	0	200
250	3	2	1	200

```sql
SELECT order_id,receiver_user_id,percent,amount,reason_code FROM commissions WHERE phase_id=2 AND order_id=250;
```


**Expected:**
- Repeats recorded with repeat flag.
- No commission rows for repeat sales (150, 250).
- First-two qualification unaffected by repeats.

---
Generated: 2025-08-16 10:01:26Z
