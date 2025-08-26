CREATE TABLE IF NOT EXISTS phase_sponsor_of_record (
  member_id INT NOT NULL,
  phase_no INT NOT NULL,
  sponsor_member_id INT NOT NULL,
  iq_member_id INT NOT NULL,
  established_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (member_id, phase_no)
);



