# PROOF — Challenge Store (Unlocks, Repeats, Fixed %, MLM Integrated)
Generated: 2025-08-14T20:19:50Z UTC

## Challenge Catalog Structure

### Categories
```
1  App Challenges  app
```

### Items
```
1  1  App Challenge Series  app-series
```

### Packages (Phases)
```
1  1  0  Phase 0 (Free)  0.00    0
2  1  1  Phase 1         100.00  1
3  1  2  Phase 2         200.00  1
4  1  3  Phase 3         300.00  1
```

### Fixed Commission Matrix
```
0  0.00    0.1000  0.3000  0.4000
1  100.00  0.1000  0.3000  0.4000
2  200.00  0.1000  0.3000  0.4000
3  300.00  0.1000  0.3000  0.4000
```

## Member Challenge State (member 900)
```
900  0  2025-08-15 01:49:50  NULL                 0  0
900  1  2025-08-15 01:49:50  2025-08-15 01:49:50  0  1
900  2  2025-08-15 01:49:50  NULL                 0  0
900  3  2025-08-15 01:49:50  NULL                 1  0
```

## Challenge Attempts (counts)
```
1  2  1
2  1  0
```

## Sale Records (annotated)
```
900  100  1  0  2025-08-15 01:49:50
900  200  2  0  2025-08-15 01:49:50
900  100  1  1  2025-08-15 01:49:50
```

## Commissions (payer=900)
```
900  1    30.00  CHALLENGE_IQ_P1
900  1    30.00  CHALLENGE_IQ_P1
900  1    60.00  CHALLENGE_IQ_P2
900  800  10.00  CHALLENGE_IT_P1
900  800  10.00  CHALLENGE_IT_P1
900  800  20.00  CHALLENGE_IT_P2
```

## Test Results Summary

### ✅ Expected Behaviors Verified:
- **Phase 0 Bootstrap**: Phase 0 exists by default; Phase 1 is purchasable
- **Sequential Unlock**: After completing Phase 1, Phase 2 is unlocked and purchasable
- **Repeat Detection**: Repeat purchase of Phase 1 is recorded with repeat_flag=1
- **Admin Override**: Admin can unlock any phase (Phase 3 unlocked manually)
- **Commission Integration**: Fixed percentages (10/30/40) applied to challenge purchases
- **SoR Preservation**: Repeats pay the same sponsor/upline structure
- **No BV Dependency**: All commission math uses fixed percentages from phase_fixed_commission

### 🏗️ Catalog Management:
- **Hierarchical Structure**: Categories → Items → Packages (Phases)
- **Flexible Pricing**: Per-phase price configuration
- **Unlock Logic**: Configurable requires_prev flag per package
- **Membership Gating**: Optional membership type restrictions

### 📊 Purchase Flow:
1. Member registers → Phase 0 auto-unlocked
2. Phase 1 available for purchase (always_available or completed Phase 0)
3. Purchase Phase 1 → Commissions paid to upline
4. Complete Phase 1 → Phase 2 auto-unlocked (if auto_unlock_next_on_complete=true)
5. Repeat purchases allowed → Same commission structure, no progression

### 🔧 Admin Controls:
- Create/edit/delete categories, items, packages
- Manual phase unlock for any member
- Mark phases as completed
- View member progress and purchase history
- Challenge order management and reporting

