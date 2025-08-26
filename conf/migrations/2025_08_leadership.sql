CREATE TABLE IF NOT EXISTS leadership_rank (
  user_id       INT PRIMARY KEY,
  `rank`        ENUM('ASSISTANT_NTM','NTM','VP','PRESIDENT','RD') NOT NULL,
  qualified     TINYINT(1) NOT NULL DEFAULT 1,
  qualified_at  DATETIME NULL,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS leadership_assignment (
  assignment_id  BIGINT AUTO_INCREMENT PRIMARY KEY,
  leader_id      INT NOT NULL,
  member_id      INT NOT NULL,
  active         TINYINT(1) NOT NULL DEFAULT 1,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_leader_member (leader_id, member_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS leadership_earnings (
  le_id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  week_id        INT NOT NULL,
  leader_id      INT NOT NULL,
  member_id      INT NOT NULL,
  basis_amount   DECIMAL(12,2) NOT NULL,
  percent        DECIMAL(6,4) NOT NULL,
  amount         DECIMAL(12,2) NOT NULL,
  reason_code    VARCHAR(32) NOT NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE cron_1week
  ADD COLUMN statusLeadership ENUM('Yes','No') NOT NULL DEFAULT 'No';

