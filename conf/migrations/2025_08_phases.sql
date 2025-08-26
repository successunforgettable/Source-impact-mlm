-- Phases & capacity-controlled instances
CREATE TABLE IF NOT EXISTS phase (
  phase_id      INT AUTO_INCREMENT PRIMARY KEY,
  phase_no      INT NOT NULL,
  entry_price   DECIMAL(12,2) NOT NULL,
  active        TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uniq_phase_no (phase_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS phase_instance (
  instance_id   INT AUTO_INCREMENT PRIMARY KEY,
  phase_id      INT NOT NULL,
  seq_no        INT NOT NULL,
  status        ENUM('recruiting','active','completed') NOT NULL DEFAULT 'recruiting',
  capacity      INT NOT NULL DEFAULT 500,
  filled_count  INT NOT NULL DEFAULT 0,
  started_at    DATETIME NULL,
  ended_at      DATETIME NULL,
  FOREIGN KEY (phase_id) REFERENCES phase(phase_id),
  UNIQUE KEY uniq_phase_seq (phase_id, seq_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Enrollment (per phase/instance) + Two-Up progress inside that phase
CREATE TABLE IF NOT EXISTS phase_enrollment (
  enroll_id           INT AUTO_INCREMENT PRIMARY KEY,
  member_id           INT NOT NULL,
  phase_id            INT NOT NULL,
  instance_id         INT NOT NULL,
  role_in_phase       ENUM('IT','IQ') NOT NULL DEFAULT 'IT',
  first_two_count     TINYINT NOT NULL DEFAULT 0,
  original_sponsor_id  INT NOT NULL,
  permanent_sponsor_id INT NULL,
  qualified_at        DATETIME NULL,
  joined_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_member_phase (member_id, phase_id),
  KEY idx_enroll_phase (phase_id, instance_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Optional: record compression decisions for audit
CREATE TABLE IF NOT EXISTS compression_log (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  recruit_user_id INT NOT NULL,
  intended_iq_id  INT NOT NULL,
  receiver_iq_id  INT NOT NULL,
  phase_id        INT NOT NULL,
  instance_id     INT NOT NULL,
  reason          VARCHAR(64) NOT NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Phase-aware columns on existing audit/ledger tables
ALTER TABLE passup_event
  ADD COLUMN phase_id INT NULL,
  ADD COLUMN instance_id INT NULL;

ALTER TABLE commissions
  ADD COLUMN phase_id INT NULL,
  ADD COLUMN instance_id INT NULL;


