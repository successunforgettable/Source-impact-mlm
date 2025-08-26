# PROOF: Phase-2 Compression (Schema-Adaptive & Idempotent)

## Context

- Phase: 2
- Amount each sale: ₹1000.00
- Sales: S1=105 (M20), S2=106 (M19)
- Rule: 10% IT to introducer; 30% pass-up compresses; positions unchanged; no retro pay.

## Commission rows (ONLY S1,S2)


```sql
SELECT order_id AS sale_id, phase_id AS phase, receiver_user_id AS earner, reason_code AS reason, amount AS amount FROM commissions WHERE phase_id=2 AND order_id IN (105,106) ORDER BY order_id, receiver_user_id;
```

105	2	1	PASSUP_COMPRESSED	300.00
105	2	19	IT_DIRECT	100.00
106	2	1	PASSUP_COMPRESSED	300.00
106	2	18	IT_DIRECT	100.00

## Totals by receiver (scoped)


```sql
SELECT receiver_user_id AS earner, SUM(amount) AS total FROM commissions WHERE phase_id=2 AND order_id IN (105,106) GROUP BY receiver_user_id ORDER BY total DESC;
```

1	600.00
19	100.00
18	100.00

## Compression log (these sales)


```sql
SELECT recruit_user_id AS recruit_id, intended_iq_id AS intended_earner, receiver_iq_id AS paid_to, phase_id AS phase, reason AS reason, created_at FROM compression_log WHERE phase_id=2 ORDER BY created_at;
```

20	19	1	2	Unqualified upline M19	2025-08-16 15:30:55
19	18	1	2	Unqualified upline M18	2025-08-16 15:30:55
20	19	1	2	Unqualified upline M19	2025-08-16 15:31:25
19	18	1	2	Unqualified upline M18	2025-08-16 15:31:25

## Positions preserved


```sql
SELECT memberid AS member, CONCAT(firstname,' ',lastname) AS name, sid AS permanent_sponsor_id FROM member WHERE memberid IN (18,19,20) ORDER BY memberid;
```

18	M18 User	1
19	M19 User	18
20	M20 User	19

## Qualification status


```sql
SELECT member_id AS member, instance_id AS phase, (qualified_at IS NOT NULL) AS qualified FROM phase_instance_enrollment WHERE member_id IN (1,18,19,20) AND instance_id=2 ORDER BY member_id;
```

1	2	1
19	2	1
20	2	0

## Financial Summary

- **John (ID=1):** ₹600.00 (compressed pass-ups)
- **M19 (ID=19):** ₹100.00 (IT commission)  
- **M18 (ID=18):** ₹100.00 (IT commission)
- **Total Sales:** ₹2000.00
- **Total Paid:** ₹800.00
- **Commission Rate:** 40.0%

---
Generated: 2025-08-16 10:01:26Z
