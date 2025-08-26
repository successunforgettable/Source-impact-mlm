-- IMPACT Genealogy Database Schema
CREATE TABLE IF NOT EXISTS `member` (
  `memberid` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(100) NOT NULL,
  `sponsor_id` INT NULL,
  `role` ENUM('IT', 'IQ', 'Admin') DEFAULT 'IT',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_sponsor` (`sponsor_id`),
  FOREIGN KEY (`sponsor_id`) REFERENCES `member`(`memberid`) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS `sale` (
  `saleid` INT AUTO_INCREMENT PRIMARY KEY,
  `memberid` INT NOT NULL,
  `amount` DECIMAL(10,2) NOT NULL,
  `currency` VARCHAR(3) DEFAULT 'USD',
  `phase` INT DEFAULT 1,
  `repeat_flag` TINYINT(1) DEFAULT 0,
  `created` DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_member` (`memberid`),
  INDEX `idx_phase` (`phase`),
  FOREIGN KEY (`memberid`) REFERENCES `member`(`memberid`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `phase_instance_enrollment` (
  `enrollment_id` INT AUTO_INCREMENT PRIMARY KEY,
  `member_id` INT NOT NULL,
  `phase_no` INT NOT NULL,
  `permanent_sponsor_id` INT NULL,
  `first_two_count` INT DEFAULT 0,
  `completed_at` DATETIME NULL,
  `repeat_count` INT DEFAULT 0,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `uniq_member_phase` (`member_id`, `phase_no`),
  INDEX `idx_sponsor` (`permanent_sponsor_id`),
  FOREIGN KEY (`member_id`) REFERENCES `member`(`memberid`) ON DELETE CASCADE,
  FOREIGN KEY (`permanent_sponsor_id`) REFERENCES `member`(`memberid`) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS `commission` (
  `commid` INT AUTO_INCREMENT PRIMARY KEY,
  `saleid` INT NOT NULL,
  `earner_id` INT NOT NULL,
  `percent` DECIMAL(5,2) NOT NULL,
  `amount` DECIMAL(10,2) NOT NULL,
  `phase` INT DEFAULT 1,
  `reason_code` VARCHAR(50) NOT NULL,
  `note` TEXT NULL,
  `created` DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_sale` (`saleid`),
  INDEX `idx_earner` (`earner_id`),
  INDEX `idx_phase` (`phase`),
  INDEX `idx_reason` (`reason_code`),
  FOREIGN KEY (`saleid`) REFERENCES `sale`(`saleid`) ON DELETE CASCADE,
  FOREIGN KEY (`earner_id`) REFERENCES `member`(`memberid`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `leader_assignment` (
  `assignment_id` INT AUTO_INCREMENT PRIMARY KEY,
  `leader_id` INT NOT NULL,
  `member_id` INT NOT NULL,
  `assigned_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `active` TINYINT(1) DEFAULT 1,
  UNIQUE KEY `uniq_member_leader` (`member_id`, `leader_id`),
  INDEX `idx_leader` (`leader_id`),
  FOREIGN KEY (`leader_id`) REFERENCES `member`(`memberid`) ON DELETE CASCADE,
  FOREIGN KEY (`member_id`) REFERENCES `member`(`memberid`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `nudge_log` (
  `nudge_id` INT AUTO_INCREMENT PRIMARY KEY,
  `from_leader_id` INT NOT NULL,
  `to_member_id` INT NOT NULL,
  `template_id` VARCHAR(50) NOT NULL,
  `phase_no` INT NOT NULL,
  `message_sent` TEXT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_leader` (`from_leader_id`),
  INDEX `idx_member` (`to_member_id`),
  INDEX `idx_phase` (`phase_no`),
  FOREIGN KEY (`from_leader_id`) REFERENCES `member`(`memberid`) ON DELETE CASCADE,
  FOREIGN KEY (`to_member_id`) REFERENCES `member`(`memberid`) ON DELETE CASCADE
);
