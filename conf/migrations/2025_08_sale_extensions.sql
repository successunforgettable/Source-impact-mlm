-- Sale Extensions Migration
-- annotate sale rows that are challenge purchases

-- Check if challenge_phase column exists and add if not
SET @sql = (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE table_schema=DATABASE() AND table_name='sale' AND column_name='challenge_phase') = 0,
  'ALTER TABLE `sale` ADD COLUMN `challenge_phase` INT NULL AFTER `amount`',
  'SELECT "challenge_phase column already exists" AS msg'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Check if repeat_flag column exists and add if not  
SET @sql = (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE table_schema=DATABASE() AND table_name='sale' AND column_name='repeat_flag') = 0,
  'ALTER TABLE `sale` ADD COLUMN `repeat_flag` TINYINT(1) NOT NULL DEFAULT 0 AFTER `challenge_phase`',
  'SELECT "repeat_flag column already exists" AS msg'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;


