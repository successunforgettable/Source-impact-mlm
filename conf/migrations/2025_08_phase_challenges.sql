-- Phase Challenges System Migration
-- Transform products into phase-based challenges

-- New member phase unlock tracking
CREATE TABLE IF NOT EXISTS member_phase_unlock (
    id INT AUTO_INCREMENT PRIMARY KEY,
    memberid INT UNSIGNED NOT NULL,
    phase_number INT NOT NULL,
    unlocked_by_admin BOOLEAN DEFAULT FALSE,
    unlocked_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_member_phase (memberid, phase_number),
    FOREIGN KEY (memberid) REFERENCES member(memberid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Phase commission matrix
CREATE TABLE IF NOT EXISTS phase_commission (
    id INT AUTO_INCREMENT PRIMARY KEY,
    phase_number INT NOT NULL,
    level INT NOT NULL,
    commission_percent DECIMAL(5,2) NOT NULL,
    UNIQUE KEY unique_phase_level (phase_number, level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Add phase system columns to existing tables (check if columns exist first)
SET @sql = (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE table_schema=DATABASE() AND table_name='product_package' AND column_name='phase_number') = 0,
  'ALTER TABLE product_package ADD COLUMN phase_number INT DEFAULT 0 AFTER packageid',
  'SELECT "phase_number column already exists" AS msg'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE table_schema=DATABASE() AND table_name='product_package' AND column_name='unlock_condition') = 0,
  'ALTER TABLE product_package ADD COLUMN unlock_condition ENUM(''always_available'',''previous_phase_completed'',''admin_unlock'') DEFAULT ''always_available''',
  'SELECT "unlock_condition column already exists" AS msg'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE table_schema=DATABASE() AND table_name='product_package' AND column_name='completion_unlocks_next') = 0,
  'ALTER TABLE product_package ADD COLUMN completion_unlocks_next BOOLEAN DEFAULT TRUE',
  'SELECT "completion_unlocks_next column already exists" AS msg'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE table_schema=DATABASE() AND table_name='sale' AND column_name='repeat_flag') = 0,
  'ALTER TABLE sale ADD COLUMN repeat_flag BOOLEAN DEFAULT FALSE',
  'SELECT "repeat_flag column already exists" AS msg'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE table_schema=DATABASE() AND table_name='sale' AND column_name='phase_number') = 0,
  'ALTER TABLE sale ADD COLUMN phase_number INT DEFAULT 0',
  'SELECT "phase_number column already exists in sale" AS msg'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE table_schema=DATABASE() AND table_name='product_gallery' AND column_name='challenge_flag') = 0,
  'ALTER TABLE product_gallery ADD COLUMN challenge_flag BOOLEAN DEFAULT TRUE',
  'SELECT "challenge_flag column already exists" AS msg'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE table_schema=DATABASE() AND table_name='product_category' AND column_name='category_type') = 0,
  'ALTER TABLE product_category ADD COLUMN category_type ENUM(''product'',''challenge'') DEFAULT ''challenge''',
  'SELECT "category_type column already exists" AS msg'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Insert default commission matrix for phases 0-10
INSERT IGNORE INTO phase_commission (phase_number, level, commission_percent) VALUES
(0, 1, 0.00), (0, 2, 0.00), (0, 3, 0.00),
(1, 1, 10.00), (1, 2, 5.00), (1, 3, 2.50),
(2, 1, 15.00), (2, 2, 7.50), (2, 3, 3.75),
(3, 1, 20.00), (3, 2, 10.00), (3, 3, 5.00),
(4, 1, 25.00), (4, 2, 12.50), (4, 3, 6.25),
(5, 1, 30.00), (5, 2, 15.00), (5, 3, 7.50),
(6, 1, 35.00), (6, 2, 17.50), (6, 3, 8.75),
(7, 1, 40.00), (7, 2, 20.00), (7, 3, 10.00),
(8, 1, 45.00), (8, 2, 22.50), (8, 3, 11.25),
(9, 1, 50.00), (9, 2, 25.00), (9, 3, 12.50),
(10, 1, 55.00), (10, 2, 27.50), (10, 3, 13.75);

-- Default challenge categories
INSERT IGNORE INTO product_category (categoryid, title, description, category_type) VALUES
(100, 'Foundation Challenges', 'Basic level challenges for new members', 'challenge'),
(101, 'Intermediate Challenges', 'Mid-level challenges for progressing members', 'challenge'),
(102, 'Advanced Challenges', 'High-level challenges for experienced members', 'challenge');

-- Sample phase challenges (packages)
INSERT IGNORE INTO product_package (packageid, phase_number, title, description, price, sh, bv, status, typeid, unlock_condition, completion_unlocks_next) VALUES
(200, 0, 'Welcome Challenge', 'Free introductory challenge', 0.00, 0.00, 0.00, 'Yes', 1, 'always_available', true),
(201, 1, 'Phase 1: Foundation', 'Build your foundation skills', 97.00, 5.00, 0.00, 'Yes', 1, 'always_available', true),
(202, 2, 'Phase 2: Growth', 'Develop growth mindset', 197.00, 5.00, 0.00, 'Yes', 1, 'previous_phase_completed', true),
(203, 3, 'Phase 3: Leadership', 'Learn leadership principles', 297.00, 5.00, 0.00, 'Yes', 1, 'previous_phase_completed', true),
(204, 4, 'Phase 4: Mastery', 'Master advanced concepts', 497.00, 5.00, 0.00, 'Yes', 1, 'previous_phase_completed', true),
(205, 5, 'Phase 5: Innovation', 'Drive innovation and change', 797.00, 5.00, 0.00, 'Yes', 1, 'previous_phase_completed', true);

-- Auto-unlock Phase 0 for all existing members
INSERT IGNORE INTO member_phase_unlock (memberid, phase_number, unlocked_by_admin)
SELECT memberid, 0, false FROM member WHERE active = 'Yes';
