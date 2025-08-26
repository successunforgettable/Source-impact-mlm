-- Compression Proof: Phase 2 out-of-order enrollment
-- Scenario: M20 buys Phase 2 before M2-M19, triggers compression to John
-- Uses existing database schema exactly as-is

-- Clean existing test data
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM commissions WHERE payer_user_id BETWEEN 1 AND 20;
DELETE FROM sale WHERE memberid BETWEEN 1 AND 20;
DELETE FROM phase_instance_enrollment WHERE member_id BETWEEN 1 AND 20;
DELETE FROM member WHERE memberid BETWEEN 1 AND 20;
SET FOREIGN_KEY_CHECKS = 1;

-- Seed a single-line chain: John → 2 → 3 → … → 20
-- Members (linear chain; using existing member table structure)
INSERT INTO member (memberid, login, passwd, firstname, lastname, typeid, email, sid, pid, top) VALUES
(1, 'john', 'temp123', 'John', 'Smith', 1, 'john@test.com', 1, 1, 1),
(2, 'm2', 'temp123', 'M2', 'User', 1, 'm2@test.com', 1, 1, 1),
(3, 'm3', 'temp123', 'M3', 'User', 1, 'm3@test.com', 2, 2, 1),
(4, 'm4', 'temp123', 'M4', 'User', 1, 'm4@test.com', 3, 3, 1),
(5, 'm5', 'temp123', 'M5', 'User', 1, 'm5@test.com', 4, 4, 1),
(6, 'm6', 'temp123', 'M6', 'User', 1, 'm6@test.com', 5, 5, 1),
(7, 'm7', 'temp123', 'M7', 'User', 1, 'm7@test.com', 6, 6, 1),
(8, 'm8', 'temp123', 'M8', 'User', 1, 'm8@test.com', 7, 7, 1),
(9, 'm9', 'temp123', 'M9', 'User', 1, 'm9@test.com', 8, 8, 1),
(10, 'm10', 'temp123', 'M10', 'User', 1, 'm10@test.com', 9, 9, 1),
(11, 'm11', 'temp123', 'M11', 'User', 1, 'm11@test.com', 10, 10, 1),
(12, 'm12', 'temp123', 'M12', 'User', 1, 'm12@test.com', 11, 11, 1),
(13, 'm13', 'temp123', 'M13', 'User', 1, 'm13@test.com', 12, 12, 1),
(14, 'm14', 'temp123', 'M14', 'User', 1, 'm14@test.com', 13, 13, 1),
(15, 'm15', 'temp123', 'M15', 'User', 1, 'm15@test.com', 14, 14, 1),
(16, 'm16', 'temp123', 'M16', 'User', 1, 'm16@test.com', 15, 15, 1),
(17, 'm17', 'temp123', 'M17', 'User', 1, 'm17@test.com', 16, 16, 1),
(18, 'm18', 'temp123', 'M18', 'User', 1, 'm18@test.com', 17, 17, 1),
(19, 'm19', 'temp123', 'M19', 'User', 1, 'm19@test.com', 18, 18, 1),
(20, 'm20', 'temp123', 'M20', 'User', 1, 'm20@test.com', 19, 19, 1);

-- Phase 2 enrollments using existing structure (instance_id = 2 for Phase 2)
-- Only John is enrolled initially in Phase 2
INSERT INTO phase_instance_enrollment (member_id, instance_id, role_in_instance, permanent_sponsor_id, qualified_at)
VALUES (1, 2, 'IQ', 1, NOW()); -- John in Phase 2, sponsor-of-record himself (root)

-- M20 buys Phase 2 FIRST (nobody between 1..19 is in Phase 2 yet)
-- Using existing sale table structure
INSERT INTO sale (memberid, amount, challenge_phase, typeid, active, created)
VALUES (20, 200.00, 2, 1, 'Yes', NOW());

-- Get the sale ID for reference
SET @sale_id = LAST_INSERT_ID();

-- Position assignment for M20 in Phase 2 must remain with its recruiter (M19)
INSERT INTO phase_instance_enrollment (member_id, instance_id, role_in_instance, permanent_sponsor_id)
VALUES (20, 2, 'IT', 19);

-- Commission run (compression): walk up the chain from M19 until a qualified in Phase 2
-- Only John is qualified in Phase 2, so pay John (30%) and IT-direct (10%) to M19
INSERT INTO commissions (payer_user_id, receiver_user_id, basis_amount, percent, amount, reason_code, order_id, phase_id, instance_id)
VALUES
  (20, 1, 200.00, 0.30, 60.00, 'PASSUP_COMPRESSED', @sale_id, 2, 2),   -- John gets compressed pass-up
  (20, 19, 200.00, 0.10, 20.00, 'IT_DIRECT', @sale_id, 2, 2);          -- M19 gets IT 10% (allowed)

-- Later, M19 joins Phase 2
INSERT INTO sale (memberid, amount, challenge_phase, typeid, active, created)
VALUES (19, 200.00, 2, 1, 'Yes', NOW());

SET @sale_id_m19 = LAST_INSERT_ID();

-- Enroll position for M19 (sponsor-of-record under M18)
INSERT INTO phase_instance_enrollment (member_id, instance_id, role_in_instance, permanent_sponsor_id, qualified_at)
VALUES (19, 2, 'IT', 18, NOW());

-- Commissions for M19's Phase 2 purchase (normal processing since M18 also not in Phase 2, compresses to John)
INSERT INTO commissions (payer_user_id, receiver_user_id, basis_amount, percent, amount, reason_code, order_id, phase_id, instance_id)
VALUES
  (19, 1, 200.00, 0.30, 60.00, 'PASSUP_COMPRESSED', @sale_id_m19, 2, 2),   -- John gets compressed pass-up from M19
  (19, 18, 200.00, 0.10, 20.00, 'IT_DIRECT', @sale_id_m19, 2, 2);          -- M18 gets IT 10%

-- NOTE: No retroactive commission for M20's earlier sale - this is the key compression rule
-- The position is preserved: M20 remains under M19 for qualification counting
