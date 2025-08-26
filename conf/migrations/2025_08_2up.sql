-- Two-Up plan migration

-- 1) Member columns: tracking_sponsor_id, real_sponsor_id, passups_given
ALTER TABLE member 
  ADD COLUMN IF NOT EXISTS tracking_sponsor_id INT NULL,
  ADD COLUMN IF NOT EXISTS real_sponsor_id INT NULL,
  ADD COLUMN IF NOT EXISTS passups_given TINYINT NOT NULL DEFAULT 0;

-- MySQL before 8.0.29 may not support IF NOT EXISTS on columns; fallback guards:
-- ALTER TABLE member ADD COLUMN tracking_sponsor_id INT NULL;
-- ALTER TABLE member ADD COLUMN real_sponsor_id INT NULL;
-- ALTER TABLE member ADD COLUMN passups_given TINYINT NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_member_tracking_sponsor ON member(tracking_sponsor_id);
CREATE INDEX IF NOT EXISTS idx_member_real_sponsor ON member(real_sponsor_id);

-- 2) Pass-up audit table
CREATE TABLE IF NOT EXISTS passup_event (
  event_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  recruit_user_id INT NOT NULL,
  recruiter_user_id INT NOT NULL,
  receiver_user_id INT NOT NULL,
  reason ENUM('PASSUP_1','PASSUP_2','KEEPER_3PLUS','COMPRESSED') NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- 3) Optional commissions table (future use)
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- 4) Weekly status flag
ALTER TABLE cron_1week 
  ADD COLUMN IF NOT EXISTS statusTwoUp ENUM('Yes','No') NOT NULL DEFAULT 'No';

-- Fallback if IF NOT EXISTS unsupported:
-- ALTER TABLE cron_1week ADD COLUMN statusTwoUp ENUM('Yes','No') NOT NULL DEFAULT 'No';
