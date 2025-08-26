# Challenge Store System Documentation

## Overview

The Challenge Store is a phase-based progression system that transforms traditional products into sequential challenges. Members progress through phases 0-10+ with automatic unlocking, repeat purchases, and integrated MLM commission structures.

## System Architecture

### Database Schema

#### Core Tables

**challenge_category**
- Primary catalog organization
- Categories like "App Challenges", "Business Challenges"
- Supports slugs and active/inactive states

**challenge_item** 
- Individual challenge series within categories
- Contains title, description, images
- Links to category via foreign key

**challenge_package**
- Purchasable phase SKUs (Phase 0, Phase 1, etc.)
- Price configuration per phase
- Unlock requirements (`always_available`, `previous_phase_completed`, `admin_unlock`)

**member_challenge_state**
- Tracks member progress per phase
- Unlock timestamps, completion status
- Repeat purchase counts
- Admin unlock flags

**member_challenge_attempt**
- Audit trail of all purchase attempts
- Tracks repeat purchases with `is_repeat` flag
- Links to order IDs for commission tracking

**phase_fixed_commission**
- Commission matrix per phase
- IT/IQ/Keeper percentages (typically 10%/30%/40%)
- Overrides BV calculations with fixed rates

### Phase Progression Logic

#### Phase 0 (Bootstrap)
- **Free entry phase**
- Auto-unlocked on member registration
- Establishes member in the challenge system
- No purchase required

#### Phase 1+ (Paid Challenges)
- **Sequential unlock system**
- Phase N unlocks Phase N+1 upon completion
- Configurable pricing per phase
- Admin override capability

#### Repeat Purchases
- **Same phase re-purchase allowed**
- Marked with `repeat_flag=1` in sales
- Same commission structure applies
- No progression requirements enforced
- Increment repeat counter in member state

### Commission Integration

#### Fixed Percentage System
- **No BV calculations** - uses `phase_fixed_commission` table
- **IT Commission**: 10% to direct recruiter
- **IQ Commission**: 30% to sponsor's upline
- **Keeper**: 40% retained by company/system
- **SoR Preservation**: Repeats pay same sponsor structure

#### MLM Integration
- Preserves existing 2-Up logic
- Works alongside Phases and Leadership compensation
- Commission booking via existing `commissions` table
- Reason codes: `CHALLENGE_IT_P{N}`, `CHALLENGE_IQ_P{N}`

## Admin Interface

### Challenge Management

#### Categories Tab
- Create/edit/delete challenge categories
- Slug management for URL-friendly names
- Active/inactive toggle

#### Items Tab
- Manage challenge series within categories
- Upload challenge images and descriptions
- Link items to categories

#### Packages Tab
- Configure phase-based packages
- Set pricing, unlock conditions
- Phase number assignment (0-99)
- Requires previous phase toggle

#### Member Unlocks Tab
- **Manual Phase Unlock**: Admin can unlock any phase for any member
- **Mark Completion**: Manually mark phases as completed
- **Progress Viewing**: See member progression status

#### Orders Tab
- View all challenge purchases
- Filter by member, phase, repeat status
- Track commission payments

### Access Control
- Admin role required for all challenge management
- Integrated with existing admin authentication
- Menu item: Challenges → Challenge Store

## API/Model Layer

### MLM::Challenge::Store
**Core business logic for challenge progression**

```perl
# Phase unlock management
$store->ensure_phase0_and_phase1_unlocked($member_id);
$store->admin_unlock_phase($member_id, $phase_number);
$store->is_phase_unlocked_for_member($member_id, $phase_number);

# Completion and progression
$store->mark_completed_and_maybe_unlock_next($member_id, $phase_number);
$store->record_purchase_and_attempt($member_id, $phase_number, $amount, $order_id, $is_repeat);

# Progress tracking
$store->get_member_challenge_progress($member_id);
$store->get_available_packages($member_id);
```

### MLM::Challenge::Purchase
**Purchase flow and commission processing**

```perl
# Main purchase handler
$purchase->handle_challenge_purchase($buyer_id, $recruiter_id, $phase_number, $order_id);

# Returns: { order_id, amount, phase_number, repeat => 0|1 }
```

### MLM::Challenge::Model
**Admin operations and catalog management**

```perl
# Catalog management
$model->get_challenge_categories();
$model->get_challenge_items($category_id);
$model->get_challenge_packages($item_id);

# CRUD operations
$model->create_challenge_category($name, $slug);
$model->create_challenge_item($category_id, $title, $slug, $description, $image_url);
$model->create_challenge_package($item_id, $phase_number, $title, $price, $requires_prev, $image_url);

# Admin functions
$model->admin_unlock_member_phase($member_id, $phase_number);
$model->mark_member_phase_completed($member_id, $phase_number);
$model->get_member_progress($member_id);
$model->get_member_challenge_orders($member_id);
```

## Configuration

### config.json Settings
```json
{
  "Custom": {
    "Challenges": {
      "enabled": true,
      "auto_unlock_next_on_complete": true,
      "enforce_requires_prev": true
    },
    "TwoUp": {
      "it_percent": 0.10,
      "upline_percent": 0.30,
      "keeper_percent": 0.40,
      "reuse_sponsor_on_repeats": true
    }
  }
}
```

### Commission Matrix Example
```sql
INSERT INTO phase_fixed_commission (phase_number, price, it_percent, iq_percent, keeper_percent) VALUES
(0, 0.00, 0.10, 0.30, 0.40),      -- Free phase
(1, 100.00, 0.10, 0.30, 0.40),    -- Phase 1: $100
(2, 200.00, 0.10, 0.30, 0.40),    -- Phase 2: $200
(3, 300.00, 0.10, 0.30, 0.40);    -- Phase 3: $300
```

## Purchase Flow

### New Member Journey
1. **Registration** → Phase 0 auto-unlocked
2. **Phase 1 Available** → Purchase for $100
3. **Commission Paid** → IT: $10, IQ: $30, Keeper: $40
4. **Completion** → Phase 2 auto-unlocked
5. **Phase 2 Purchase** → $200 with same commission structure
6. **Repeat Option** → Can re-purchase any completed phase

### Repeat Purchase Flow
1. **Member returns** to completed phase
2. **Same pricing** and commission structure
3. **Repeat flag set** → `sale.repeat_flag = 1`
4. **No progression** → Doesn't unlock next phase
5. **Commission paid** → Same upline/sponsor structure

### Admin Override Flow
1. **Admin access** → Challenge Store interface
2. **Manual unlock** → Any phase for any member
3. **Bypass requirements** → `unlocked_by_admin = 1`
4. **Immediate availability** → Member can purchase

## Testing & Validation

### E2E Test Harness
```bash
make test-challenges
```
- Schema validation (tables, columns)
- Purchase flow testing (new/repeat)
- Commission verification
- Database state assertions
- Generates: `docs/TEST-CHALLENGES.md`

### Unit Tests
```bash
prove -v t/challenges.t
```
- 21 comprehensive test cases
- Phase unlock logic
- Repeat purchase detection
- Admin controls
- Database integrity

### Proof Documentation
- `docs/PROOF-CHALLENGES-FULL.md` - Complete system proof
- `docs/TEST-CHALLENGES.md` - E2E test results
- Live database snapshots and commission tracking

## Integration Points

### Existing MLM Systems
- **2-Up Logic**: Preserved and enhanced
- **Phase System**: Works alongside challenge phases
- **Leadership Compensation**: Integrated commission structure
- **Member Management**: Uses existing member table
- **Sales Tracking**: Enhanced sale table with challenge annotations

### UI Integration
- **Admin Menu**: Challenges dropdown with sub-items
- **Existing Templates**: Reuses admin template system
- **AJAX Interface**: Dynamic catalog management
- **Responsive Design**: Mobile-friendly admin interface

## Maintenance & Operations

### Regular Tasks
- Monitor phase completion rates
- Adjust commission percentages as needed
- Add new phases/challenges seasonally
- Review repeat purchase patterns

### Scaling Considerations
- Challenge catalog grows with business
- Commission matrix easily configurable
- Phase numbers support 0-99 range
- Database designed for high transaction volume

### Backup & Recovery
- All challenge data in standard MySQL tables
- Commission tracking via existing systems
- Member state recoverable from purchase history
- Admin actions logged with timestamps

## Troubleshooting

### Common Issues
- **Foreign Key Constraints**: Ensure proper deletion order (packages → items → categories)
- **Phase Unlock Logic**: Check `requires_prev` settings and completion status
- **Commission Calculation**: Verify `phase_fixed_commission` table data
- **Repeat Detection**: Ensure `member_challenge_state.completed_at` is set

### Debug Queries
```sql
-- Check member progress
SELECT * FROM member_challenge_state WHERE member_id = ?;

-- Verify commission setup
SELECT * FROM phase_fixed_commission ORDER BY phase_number;

-- Track purchase attempts
SELECT * FROM member_challenge_attempt WHERE member_id = ? ORDER BY created_at;

-- Review commission payments
SELECT * FROM commissions WHERE reason_code LIKE 'CHALLENGE_%' ORDER BY created_at DESC;
```

## Future Enhancements

### Planned Features
- **Membership Gating**: Restrict phases by membership level
- **Time-based Unlocks**: Delay phase availability by calendar
- **Group Challenges**: Team-based progression
- **Achievement Badges**: Visual progress indicators
- **Mobile App Integration**: Native mobile interface

### Extensibility
- **Custom Unlock Logic**: Plugin system for complex requirements
- **Variable Commission**: Dynamic rates based on performance
- **Challenge Templates**: Rapid deployment of new challenge series
- **Analytics Dashboard**: Progress tracking and insights


