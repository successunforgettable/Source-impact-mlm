prove-2up:
	@echo "[*] Running 2-Up proof..."
	@chmod +x bin/prove_2up.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/prove_2up.sh
	@echo "[*] Open docs/PROOF-2UP.md"

prove-phases:
	@echo "[*] Running Phases+Compression proof..."
	@chmod +x bin/prove_phases.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/prove_phases.sh
	@echo "[*] Open docs/PROOF-PHASES.md"

prove-leadership:
	@echo "[*] Running Leadership proof..."
	@chmod +x bin/prove_leadership.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/prove_leadership.sh
	@echo "[*] Open docs/PROOF-LEADERSHIP.md"


prove-combo:
	@echo "[*] Running Combined 2-Up + Phases + Leadership proof..."
	@chmod +x bin/prove_combo.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/prove_combo.sh
	@echo "[*] Open docs/PROOF-COMBO.md"

prove-repeats:
	@echo "[*] Running Repeats/Unlimited Phases proof..."
	@chmod +x bin/prove_repeats.sh
	@./bin/prove_repeats.sh
	@echo "[*] Open docs/PROOF-REPEATS.md"

prove-challenges:
	@echo "[*] Running Phase Challenges proof..."
	@chmod +x bin/prove_challenges.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/prove_challenges.sh
	@echo "[*] Open docs/PROOF-CHALLENGES.md"

prove-challenges-full:
	@echo "[*] Running Full Challenge Store proof..."
	@chmod +x bin/prove_challenges_full.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/prove_challenges_full.sh
	@echo "[*] Open docs/PROOF-CHALLENGES-FULL.md"

test-challenges:
	@echo "[*] Running Challenge Store E2E tests..."
	@chmod +x bin/test_challenge_store.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/test_challenge_store.sh
	@echo "[*] Open docs/TEST-CHALLENGES.md"

e2e-challenges:
	@echo "[*] Running E2E Challenge Store verification..."
	@chmod +x bin/e2e_challenge_store.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/e2e_challenge_store.sh
	@echo "[*] Open docs/E2E-CHALLENGE-STORE.md"

e2e-2up:
	@echo "[*] Running 2-Up E2E verification..."
	@chmod +x bin/test_2up_e2e.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/test_2up_e2e.sh
	@echo "[*] Open docs/TEST-2UP-E2E.md"

e2e-full:
	@echo "[*] Running Unified E2E verification (Challenge Store + 2-Up)..."
	@chmod +x bin/e2e_full.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/e2e_full.sh
	@echo "[*] Open docs/E2E-FULL.md"

test-feature-flags:
	@echo "[*] Testing feature flag system..."
	@chmod +x bin/test_feature_flags.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/test_feature_flags.sh
	@echo "[*] Open docs/PROOF-FEATURE-FLAGS.md"

prove-genealogy-api:
	@echo "[*] Proving IMPACT Genealogy API system..."
	@chmod +x bin/prove_genealogy_api.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/prove_genealogy_api.sh
	@echo "[*] Open docs/PROOF-GENEALOGY-API.md"

prove-adaptive:
	@echo "[*] Running Schema-Adaptive Compression + Repeater Proofs..."
	@mkdir -p bin docs
	@chmod +x bin/prove_adaptive.sh
	@DB_USER=mlm_user DB_PASS=mlm_password123 DB_NAME=mlm_system ./bin/prove_adaptive.sh
	@echo "[*] Open docs/PROOF-COMPRESSION.md and docs/PROOF-REPEATER.md"

migrate-points:
	@echo "[*] Migrating Points Wallet database schema..."
	@mysql -u$(DB_USER) -p$(DB_PASS) $(DB_NAME) < sql/001_points_wallet.sql
	@echo "[*] Points Wallet tables created successfully"

backfill-points:
	@echo "[*] Backfilling commission data to points ledger..."
	@chmod +x bin/backfill_points_simple.sh
	@DB_NAME=$(DB_NAME) DB_USER=$(DB_USER) DB_PASS=$(DB_PASS) ./bin/backfill_points_simple.sh
	@echo "[*] Points backfill completed"

prove-points:
	@echo "[*] Generating Points Wallet backfill proof..."
	@chmod +x bin/prove_points_backfill.sh
	@DB_NAME=$(DB_NAME) DB_USER=$(DB_USER) DB_PASS=$(DB_PASS) ./bin/prove_points_backfill.sh
	@echo "[*] Open docs/PROOF-POINTS-BACKFILL.md"

prove-realtime-points:
	@echo "[*] Proving real-time points integration..."
	@chmod +x bin/prove_realtime_points.sh
	@DB_NAME=$(DB_NAME) DB_USER=$(DB_USER) DB_PASS=$(DB_PASS) ./bin/prove_realtime_points.sh
	@echo "[*] Open docs/PROOF-REALTIME-POINTS.md"

setup-points: migrate-points backfill-points prove-points
	@echo "[*] Complete Points Wallet setup finished!"
	@echo "[*] System ready for real-time points accumulation"

migrate-points-keys:
	@echo "[*] Adding unique constraints and performance indexes to points_ledger..."
	@mysql -u$(DB_USER) -p$(DB_PASS) $(DB_NAME) < sql/000_points_ledger_keys.sql
	@echo "[*] Points ledger indexes created successfully"

sync-points:
	@echo "[*] Running comprehensive points synchronization..."
	@chmod +x bin/points_backfill_and_verify.sh
	@DB_NAME=$(DB_NAME) DB_USER=$(DB_USER) DB_PASS=$(DB_PASS) BATCH=$(BATCH) ./bin/points_backfill_and_verify.sh
	@echo "[*] Open docs/PROOF-POINTS-SYNC.md"

verify-points:
	@echo "[*] Verifying commission-to-points sync integrity..."
	@chmod +x bin/verify_points_sync.sh
	@DB_NAME=$(DB_NAME) DB_USER=$(DB_USER) DB_PASS=$(DB_PASS) ./bin/verify_points_sync.sh

setup-points-full: setup-points prove-realtime-points
	@echo "[*] Complete Points Wallet with real-time integration finished!"
	@echo "[*] System ready for production use"

setup-points-complete: migrate-points-keys setup-points-full sync-points verify-points
	@echo "[*] Complete Points Wallet with 100% sync achieved!"
	@echo "[*] System ready for production with verified data integrity"


