-- 001_points_wallet.sql
-- IMPACT Points Wallet Database Migration
-- Creates points_ledger table and wallet_balance view

CREATE TABLE IF NOT EXISTS points_ledger (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  memberid      BIGINT NOT NULL,
  phase         INT NULL,
  saleid        BIGINT NULL,
  source_code   ENUM('IT','PASSUP','KEEPER','UPGRADE','WITHDRAWAL','ADJUST') NOT NULL,
  points        DECIMAL(14,2) NOT NULL,
  currency      ENUM('USD','INR') NOT NULL,
  note          VARCHAR(255) NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_pl_member (memberid),
  INDEX idx_pl_member_phase (memberid, phase),
  INDEX idx_pl_sale (saleid),
  INDEX idx_pl_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Current balance per member (Total = Encashable)
CREATE OR REPLACE VIEW wallet_balance AS
SELECT memberid, 
       SUM(points) AS balance,
       currency,
       COUNT(*) AS transaction_count,
       MAX(created_at) AS last_transaction
FROM points_ledger
GROUP BY memberid, currency;


