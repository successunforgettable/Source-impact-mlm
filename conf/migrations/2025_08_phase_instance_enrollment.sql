CREATE TABLE IF NOT EXISTS phase_instance_enrollment (
  member_id INT NOT NULL,
  instance_id BIGINT NOT NULL,
  role_in_instance ENUM('IT','IQ') NOT NULL DEFAULT 'IT',
  first_two_count INT NOT NULL DEFAULT 0,
  permanent_sponsor_id INT NULL,
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  qualified_at DATETIME NULL,
  PRIMARY KEY (member_id, instance_id),
  KEY (instance_id),
  KEY (member_id)
);



