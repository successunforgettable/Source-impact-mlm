-- Phase Fixed Commission Migration
-- Fixed % per phase for integration; 2-Up will still use 10/30/40, but this table
-- lets us override per-phase price or per-phase add-ons if needed

CREATE TABLE IF NOT EXISTS `phase_fixed_commission` (
  `phase_number` INT PRIMARY KEY,
  `price`        DECIMAL(12,2) NOT NULL,      -- canonical price for the challenge
  `it_percent`   DECIMAL(6,4)  NOT NULL,      -- typically 0.10
  `iq_percent`   DECIMAL(6,4)  NOT NULL,      -- typically 0.30
  `keeper_percent` DECIMAL(6,4) NOT NULL      -- typically 0.40
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


