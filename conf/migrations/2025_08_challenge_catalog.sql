-- Challenge Catalog System Migration
-- Proper challenge category, items, packages structure per prompt requirements

CREATE TABLE IF NOT EXISTS `challenge_category` (
  `category_id` INT AUTO_INCREMENT PRIMARY KEY,
  `name`        VARCHAR(120) NOT NULL,
  `slug`        VARCHAR(120) NOT NULL UNIQUE,
  `active`      TINYINT(1) NOT NULL DEFAULT 1,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `challenge_item` (
  `item_id`     INT AUTO_INCREMENT PRIMARY KEY,
  `category_id` INT NOT NULL,
  `title`       VARCHAR(180) NOT NULL,
  `slug`        VARCHAR(180) NOT NULL UNIQUE,
  `description` TEXT,
  `image_url`   VARCHAR(512) NULL,
  `active`      TINYINT(1) NOT NULL DEFAULT 1,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY (`category_id`),
  CONSTRAINT `fk_item_cat` FOREIGN KEY (`category_id`) REFERENCES `challenge_category`(`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- A package is the purchasable "challenge phase" SKU
CREATE TABLE IF NOT EXISTS `challenge_package` (
  `package_id`     INT AUTO_INCREMENT PRIMARY KEY,
  `item_id`        INT NOT NULL,
  `phase_number`   INT NOT NULL,                 -- Phase 0..N
  `title`          VARCHAR(180) NOT NULL,
  `price`          DECIMAL(12,2) NOT NULL,
  `active`         TINYINT(1) NOT NULL DEFAULT 1,
  `requires_prev`  TINYINT(1) NOT NULL DEFAULT 1, -- if 1: must complete (phase_number-1) unless admin unlocked or repeat
  `image_url`      VARCHAR(512) NULL,
  `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `uniq_item_phase` (`item_id`,`phase_number`),
  KEY (`phase_number`),
  CONSTRAINT `fk_pack_item` FOREIGN KEY (`item_id`) REFERENCES `challenge_item`(`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Optional: restrict visibility by membership type (free, silver, gold, etc.)
CREATE TABLE IF NOT EXISTS `challenge_package_membership` (
  `package_id`      INT NOT NULL,
  `membership_type` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`package_id`,`membership_type`),
  CONSTRAINT `fk_pack_mem_package` FOREIGN KEY (`package_id`) REFERENCES `challenge_package`(`package_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


