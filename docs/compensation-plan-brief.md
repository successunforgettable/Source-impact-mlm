# MLM Compensation Plan Development Brief

This document gives an implementation-level description of the MLM software and the exact steps needed to add a new compensation plan.

## 1) System Overview

- Language/Framework: Perl on the Genelet framework (MVC)
- Storage: MySQL
- Web: CGI (or FastCGI)
- Templating: Template Toolkit (TT)
- Directory layout (root: `/Users/arfeenkhan/mlm-project/mlm`)
  - `lib/MLM/**`: application code (Models, Filters, component metadata) per domain
  - `views/**`: TT templates per role/language/object
  - `conf/**`: SQL migrations, weekly-table builder, configuration
  - `www/**`: static files; `www/cgi-bin/goto` is the main CGI entry
  - `bin/**`: scripts (e.g., daily job)
- Main configuration: `conf/config.json`
  - Important keys: `Document_root`, `Server_url`, `Script`, `Template`, `Db`, `Custom`, `Roles`

## 2) Request Routing

- Entry script: `www/cgi-bin/goto` → `Genelet::Dispatch::run`
- URL form: `/{script}/{role}/{tag}/{object}?action=...`
  - Example: `/cgi-bin/goto/a/en/income?action=topics&classify=binary`
- Roles:
  - `p`: public
  - `m`: member
  - `a`: admin
- Objects: `member`, `income`, `placement`, `sponsor`, etc.
- Actions: `topics`, `edit`, `update`, `insert`, `delete`, etc. (controlled via component metadata)

## 3) Where Compensation Logic Lives

- Plans are implemented in `lib/MLM/Income/Model.pm`
- Component/action declarations and HTTP method allowances: `lib/MLM/Income/component.json`
- Admin views (reports): `views/a/income/*.en`
- Weekly-table builder: `conf/08_weekly.pl` (pre-fills `cron_1week`/`cron_4week`)
- Daily job: `bin/run_daily.pl` (call your plan here in production)

Typical model hooks for a new plan “X”:
- `is_week1_x($weekRow)`: eligibility check for the weekly window
- `week1_x($weekRow)`: compute details for the period
- `weekly_x($weekRow)`: persist to `income`/`income_amount` and (optionally) `income_ledger`
- `done_week1_x($weekRow)`: mark the weekly window as processed (update a status column in `cron_1week`)

## 4) Database: Key Tables

- `cron_1week(c1_id, daily, weekly, statusBinary, statusUp, statusAffiliate, ...)`
  - Add your plan’s flag, e.g., `statusX enum('Yes','No') DEFAULT 'No'`
- `cron_4week(...)`: monthly windows
- `member(...)`: member master data
- `def_type(typeid, short, name, bv, price, yes21, c_upper)`: member type metadata
- Income/rewards:
  - `income`: one row per credited member per period
  - `income_amount`: optional detail rows per `income`
  - `income_ledger`: actual ledger credits; split to shop/withdraw using `RATE_shop` in config
- Commerce/trees (often referenced):
  - `sale`, `sale_lineitem` (retail)
  - `family`, `family_leftright` (binary genealogy)
  - `member_signup` (new signups)

## 5) Configuration (conf/config.json)

- `Db`: `["dbi:mysql:mlm_system:localhost:3306","mlm_user","mlm_password123"]`
- `Custom`: global plan parameters
  - Add your plan’s parameters here (rates, caps, lists)
- `Roles`: cookie domains, attributes, issuers. For `m` and `a`, DB login is via stored procs and SQL (see SAMPLE_config.json)

Example extension in `Custom`:
```json
"Custom": {
  "...": "...",
  "X": { "rate": 0.05, "cap": 100, "eligibilityTypeIds": [1,2,3] }
}
```

## 6) Adding a New Plan “X” – Implementation Checklist

1) **DB migration**
- Add a weekly status column to `cron_1week`:
```sql
ALTER TABLE cron_1week ADD COLUMN statusX enum('Yes','No') DEFAULT 'No';
```
- If your plan needs aux tables, create them here.

2) **Config parameters**
- Add plan knobs to `conf/config.json` → `Custom.X` (e.g., `rate`, `cap`).

3) **Component metadata**
- Edit `lib/MLM/Income/component.json`:
  - Add actions (for admin views or JSON endpoints).
  - For any new GET endpoints, add `"method": ["GET"]`.

4) **Model code**
- Edit `lib/MLM/Income/Model.pm`:
  - Add (at minimum):
    - `is_week1_x($week)`
    - `week1_x($week)` → compute and prepare results
    - `weekly_x($week)` → write to `income` and ledger (if needed)
    - `done_week1_x($week)` → `UPDATE cron_1week SET statusX='Yes' ...`
  - In orchestration (e.g., `run_cron`, `run_daily`, `run_all_tests`), call your new hooks in sequence:
```perl
if ($self->is_week1_x($week)) {
  $self->week1_x($week);
  $self->weekly_x($week);
  $self->done_week1_x($week);
}
```
- Read `Custom.X` from `$self->{CUSTOM}->{X}`.
- Pull the weekly window from `$week` (`cron_1week` row) to bound your queries.

5) **Admin UI (optional reports)**
- Add a template under `views/a/income/` (e.g., `topics_x.en`) to display computed results.
- Link it from existing `income` pages via `component.json`.

6) **Wire to daily job**
- In `bin/run_daily.pl`, append your plan execution (after testing).

7) **Weekly windows**
- Prebuild windows using:
```bash
perl conf/08_weekly.pl -c conf/config.json 2024-01-01
```

## 7) HTTP/GET Rules

- For security, GET is restricted. If you need GET-driven pages for your plan, explicitly grant it in `lib/MLM/Income/component.json`:
```json
"topics_x": { "method": ["GET"] }
```

## 8) Testing & QA

- Unit tests: mirror existing tests (`lib/MLM/Admin/admin.t`, `lib/MLM/Placement/placement.t`) to create a test for your plan’s model flows.
- Functional tests: follow `conf/SAMPLE_bin/*` patterns.
- Seed data: `conf/03_setup.sql` seeds admin/member; add mock sales/genealogy to exercise your logic.
- Weekly/monthly windows: ensure `cron_1week`/`cron_4week` are filled.

## 9) Admin Routes to Inspect

- Base: `http://localhost:8083/cgi-bin/goto/a/en/member?action=topics`
- Income reports:
  - Direct: `.../a/en/income?action=topics&classify=direct`
  - Binary: `.../a/en/income?action=topics&classify=binary`
  - Match-Up: `.../a/en/income?action=topics&classify=matchup`
  - Affiliate: `.../a/en/income?action=topics&classify=affiliate`
- Add your own: `.../a/en/income?action=topics_x` (after wiring)

## 10) Key Paths (Agent Will Touch)

- Entry CGI: `www/cgi-bin/goto`
- Config: `conf/config.json`
- Weekly builder: `conf/08_weekly.pl`
- Compensation model: `lib/MLM/Income/Model.pm`
- Component actions/permissions: `lib/MLM/Income/component.json`
- Admin views: `views/a/income/*.en`
- Daily job: `bin/run_daily.pl`
- Schema/data: `conf/01_init.sql`, `conf/03_setup.sql`

## 11) Conventions & Notes

- Idempotency: always guard weekly runs using your `statusX` column, and mark done afterward.
- Don’t put heavy compute in view actions; compute in model hooks.
- Use config-driven parameters (`Custom.X`) instead of hardcoding.
- When crediting balances, split using `RATE_shop` in config and write to `income_ledger`.
- If you expose new GET endpoints, declare `"method": ["GET"]` in component metadata.
- Testing: ensure your logic handles empty/no-sales weeks gracefully.

---

## Appendix: Useful Commands (Local)

- Start CGI:
```bash
cd /Users/arfeenkhan/mlm-project/mlm/www
python3 -m http.server 8083 --cgi --directory /Users/arfeenkhan/mlm-project/mlm/www
```

- Admin pages (direct):
```
http://localhost:8083/cgi-bin/goto/a/en/income?action=topics&classify=direct
http://localhost:8083/cgi-bin/goto/a/en/income?action=topics&classify=binary
http://localhost:8083/cgi-bin/goto/a/en/income?action=topics&classify=matchup
http://localhost:8083/cgi-bin/goto/a/en/income?action=topics&classify=affiliate
```

- Build weekly tables:
```bash
perl conf/08_weekly.pl -c conf/config.json 2024-01-01
```

This document contains everything needed to implement a new compensation plan end-to-end (DB, config, model, admin wiring, orchestration, and testing).
