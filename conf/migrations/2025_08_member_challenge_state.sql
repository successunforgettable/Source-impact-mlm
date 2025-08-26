-- Member Challenge State Migration
-- Tracks unlock/complete/repeat per member & phase

-- Tracks unlock/complete/repeat per member & phase
CREATE TABLE IF NOT EXISTS `member_challenge_state` (
  `member_id`         INT UNSIGNED NOT NULL,
  `phase_number`      INT NOT NULL,
  `unlocked_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at`      DATETIME NULL,
  `unlocked_by_admin` TINYINT(1) NOT NULL DEFAULT 0,
  `repeat_count`      INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`member_id`,`phase_number`),
  FOREIGN KEY (`member_id`) REFERENCES `member`(`memberid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Optional audit of every attempt (purchase/run), including repeats
CREATE TABLE IF NOT EXISTS `member_challenge_attempt` (
  `attempt_id`   BIGINT AUTO_INCREMENT PRIMARY KEY,
  `member_id`    INT UNSIGNED NOT NULL,
  `phase_number` INT NOT NULL,
  `order_id`     BIGINT NULL,
  `amount`       DECIMAL(12,2) NOT NULL DEFAULT 0,
  `is_repeat`    TINYINT(1) NOT NULL DEFAULT 0,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`member_id`) REFERENCES `member`(`memberid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


