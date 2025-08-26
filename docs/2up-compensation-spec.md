# 2-Up MLM Compensation Plan — Implementation Specification

## Overview
This document details the full technical implementation of a **2-Up MLM compensation plan** to replace the existing plan in the repository.  
Once implemented, **the first two personal recruits of each member are “passed up” to their sponsor**. After those two pass-ups, **all future recruits remain permanently in the original recruiter’s team**.

The system must track **two sponsor types**:
1. **Tracking Sponsor** — For genealogy tree structure
2. **Real Sponsor** — For payout eligibility

---

## Key Rules
1. **First Two Pass-Ups**  
   - Recruit #1 and Recruit #2 are automatically assigned to the **real sponsor’s** team.
   - The recruiter receives **no commission** for these two.
   - Pass-ups **count towards the sponsor’s two pass-up quota** when they join.

2. **Permanent Team After Two Pass-Ups**  
   - Starting from Recruit #3, **all recruits remain with the original recruiter**.
   - Commission for these recruits and their downline is paid to the recruiter.

3. **Sponsor Replacement**  
   - If a pass-up occurs, the “real sponsor” field is updated to the **upline sponsor**.
   - The “tracking sponsor” remains as the recruiter for genealogy reports.

4. **Commission Logic**  
   - When a new recruit joins, the system:
     1. Checks how many pass-ups the recruiter has sent.
     2. If fewer than 2, mark this recruit as a **pass-up** and send commission to the upline.
     3. If 2 or more pass-ups already given, keep this recruit under the recruiter.

---

## Data Model Changes
**Tables/Collections:**

**`users`**
| Field               | Type        | Description |
|---------------------|------------|-------------|
| id                  | UUID       | Unique user ID |
| name                | String     | Full name |
| tracking_sponsor_id | UUID       | Recruiter who brought this member in |
| real_sponsor_id     | UUID       | Current commission-eligible sponsor |
| passups_given       | Integer    | Count of pass-ups sent |

**`transactions`**
| Field         | Type        | Description |
|---------------|------------|-------------|
| id            | UUID       | Transaction ID |
| user_id       | UUID       | The recruit who triggered this payout |
| sponsor_id    | UUID       | Sponsor receiving the commission |
| amount        | Decimal    | Commission amount |
| status        | Enum       | pending/paid |

---

## Payout Logic — Step by Step
1. **On New Recruit Join Event**
   - Fetch recruiter record.
   - If `passups_given < 2`:
     - Increment `passups_given`.
     - Assign recruit’s `real_sponsor_id` to recruiter’s `real_sponsor_id`.
     - Create commission transaction for `real_sponsor_id`.
   - Else:
     - Assign recruit’s `real_sponsor_id` to recruiter’s `id`.
     - Create commission transaction for recruiter.

2. **On Pass-Up**
   - Maintain genealogy by keeping `tracking_sponsor_id` as original recruiter.
   - Ensure `real_sponsor_id` points to payout-eligible sponsor.

3. **Reporting**
   - Genealogy reports use `tracking_sponsor_id`.
   - Commission reports use `real_sponsor_id`.

---

## Example Flow
**Scenario**: Alice recruits Bob, Charlie, and David.

| Recruit | Pass-Up Status | Commission To |
|---------|---------------|---------------|
| Bob     | Pass-Up #1    | Alice’s sponsor |
| Charlie | Pass-Up #2    | Alice’s sponsor |
| David   | No Pass-Up    | Alice |

---

## Edge Cases
1. **Sponsor Deleted** — Transfer both `tracking_sponsor_id` and `real_sponsor_id` to next valid upline.
2. **Manual Adjustment** — Admin can reset `passups_given` in special cases.
3. **Multiple Joins Same Day** — Ensure transactions process in order of `created_at` timestamp.

---

## Implementation Notes for Cursor AI
- Replace **old compensation logic files** with this plan.
- Update **user model** to include `passups_given`.
- Add **migration script** to update existing database with default `passups_given = 0`.
- Create **unit tests** to verify:
  - Correct sponsor assignment
  - Correct commission payout
  - Pass-up limit enforcement
- Ensure **API endpoints** update both `tracking_sponsor_id` and `real_sponsor_id` correctly.

---

## ASCII Flow Diagram

New Recruit
|
v
Check passups_given < 2?
|– YES –> Increment passups_given –> Assign to upline (real_sponsor) –> Pay upline
|
|– NO –> Assign to recruiter (real_sponsor) –> Pay recruiter
---

**Author:** [Your Name]  
**Last Updated:** 14 Aug 2025




🧰 Cursor Prompt — “Implement IMPACT 2-Up Plan”

### Context (read carefully)
- Replace the existing compensation logic with a 2-Up plan:
  - Every member’s first 2 recruits are passed up to their upline sponsor (the real sponsor for payouts).
  - After those 2 pass-ups, all future direct recruits remain with the original recruiter permanently.
- Maintain two sponsor links per member:
  - tracking_sponsor_id → for genealogy reports (the recruiter who brought them).
  - real_sponsor_id → the payout-eligible sponsor (after pass-ups).
- Commissions:
  - On pass-up recruits: recruiter gets 0; upline gets the designated payout (we’ll wire payout later; for now, build the pass-up routing cleanly).
  - On kept recruits (3rd onward): recruiter gets the commission; no further pass-ups are required for that member.
- We will integrate phases later. This task is to cleanly implement core 2-Up with dual-sponsor tracking and idempotent payouts.

### Primary Goals
1. Add data model fields to support 2-Up and dual sponsors.
2. Implement pass-up routing (first two) and keep (3rd+) logic.
3. Ensure idempotent commission booking (no double credit on retries).
4. Expose admin/report views to inspect pass-ups vs kept recruits.
5. Add unit/functional tests for all cases.

---

### 0) Repo scan & layout (automate)
- Search the repo for:
  - income/commission booking code (likely lib/MLM/Income/Model.pm or similar)
  - existing user/member tables and sponsor genealogy
  - existing sales/orders tables used to trigger commissions
  - admin TT views under views/a/…
  - cron runners under bin/… and weekly windows under conf/…
- Summarize the relevant files, tables, and entry points you’ll modify in a short note in docs/CHANGES-2UP.md.

---

### 1) Database migrations

Create a new migration file (e.g., conf/migrations/2025_08_2up.sql) that does all of the below. If tables already exist, add columns via ALTER TABLE guarded by IF NOT EXISTS checks where the SQL dialect allows.

```sql
-- 1. Members: add dual sponsor + pass-up counter
ALTER TABLE members
  ADD COLUMN tracking_sponsor_id INT NULL,
  ADD COLUMN real_sponsor_id INT NULL,
  ADD COLUMN passups_given TINYINT NOT NULL DEFAULT 0;

CREATE INDEX idx_members_tracking_sponsor ON members(tracking_sponsor_id);
CREATE INDEX idx_members_real_sponsor ON members(real_sponsor_id);

-- 2. Commission ledger (if not present)
CREATE TABLE IF NOT EXISTS commissions (
  commission_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  payer_user_id INT NOT NULL,
  receiver_user_id INT NOT NULL,
  basis_amount DECIMAL(12,2) NOT NULL,
  percent DECIMAL(6,4) NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  reason_code VARCHAR(32) NOT NULL,
  order_id BIGINT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Pass-up events (for audit)
CREATE TABLE IF NOT EXISTS passup_event (
  event_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  recruit_user_id INT NOT NULL,
  recruiter_user_id INT NOT NULL,
  receiver_user_id INT NOT NULL,
  reason ENUM('PASSUP_1','PASSUP_2','KEEPER_3PLUS','COMPRESSED') NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Idempotency guard for weekly/daily runs (if you use cron windows)
ALTER TABLE cron_1week
  ADD COLUMN statusTwoUp ENUM('Yes','No') NOT NULL DEFAULT 'No';
```

After creating the SQL file, add a simple migration runner entry (if repo has a pattern), or document manual apply steps in docs/CHANGES-2UP.md.

---

### 2) Config

Add a TwoUp config block to conf/config.json (or your main config file):

```json
{
  "Custom": {
    "TwoUp": {
      "enabled": true,
      "it_percent": 0.00,
      "upline_percent": 0.00,
      "keeper_percent": 0.00,
      "company_member_id": 1
    }
  }
}
```

(Keep percents at 0.00 initially to ship routing without money. Set final % later.)

---

### 3) Core logic (pass-up routing)

In the commission/income model (likely `lib/MLM/Income/Model.pm`), add a handler:

- **Input**: recruiter_id, new_user_id, basis_amount, order_id
- **Flow**:
  1. Read `passups_given` for recruiter.
  2. If `< 2` (PASS-UP):
     - Atomically increment `passups_given`.
     - Set `new_user.real_sponsor_id = recruiter.real_sponsor_id` (fallback to company/upline if null).
     - Set `new_user.tracking_sponsor_id = recruiter_id`.
     - Insert `passup_event` with PASSUP_1 or PASSUP_2.
     - (Later) Book payout to `real_sponsor_id` with reason PASSUP_n.
  3. Else (KEEPER 3+):
     - Set both `real_sponsor_id` and `tracking_sponsor_id` to `recruiter_id`.
     - Insert `passup_event` with KEEPER_3PLUS.
     - (Later) Book payout to recruiter.
  4. **Idempotency**: guard via token like `JOIN:{new_user_id}` to avoid double processing.

---

### 4) Where to hook the logic

- Find the order/join success handler (where current commissions are booked).
- Call `handle_new_recruit_2up(...)` after a paid join is confirmed.
- If multiple plans coexist, feature-flag via `Custom.TwoUp.enabled`.

---

### 5) Admin / Reports

- Add `views/a/income/twoup_overview.en` to show last N `passup_event` entries and aggregates per user.
- Expose via component JSON as a GET admin page.

---

### 6) Tests

- **Unit**:
  - passups_given = 0 → PASSUP_1
  - passups_given = 1 → PASSUP_2
  - passups_given = 2 → KEEPER_3PLUS
  - Idempotency check
- **Integration**:
  - Simulate join payment → ensures handler writes expected rows.

---

### 7) Toggle payouts (after validation)

Update `Custom.TwoUp` percents and enable booking to `income_ledger` once routing is verified.

---

### 8) Developer runbook

```bash
# Apply migration
mysql -u USER -p DB_NAME < conf/migrations/2025_08_2up.sql

# Enable feature
# Set Custom.TwoUp.enabled=true in conf/config.json

# Local server
cd www && python3 -m http.server 8083 --cgi --directory /Users/arfeenkhan/mlm-project/mlm/www
```

---

### 9) Acceptance Criteria

- First two recruits always routed to upline with audit trail.
- 3rd+ recruits stay with recruiter permanently.
- Idempotent processing (no double payouts).
- Admin report shows pass-ups/keepers.
- Tests pass.

---

### 10) Commit plan

1. `feat(2up):` migrations for dual sponsors, pass-up counter, events, ledger
2. `feat(2up):` core routing + idempotency helpers
3. `feat(2up):` hook handler into order success
4. `feat(2up):` admin overview page
5. `test(2up):` unit + integration tests
6. `chore(2up):` docs and runbook
7. `feat(2up):` enable payout percents and booking

---

### Notes for Cursor

- Reuse repo DB helpers/models for consistency.
- Feature-flag via `Custom.TwoUp.enabled`.
- Disable legacy plans via config if needed and record in `docs/CHANGES-2UP.md`.
