CREATE TABLE infobot (
	phrase VARCHAR(255) NOT NULL,
	relates ENUM('is', 'are') NOT NULL DEFAULT 'is',
	value TEXT NULL,
	locked TINYINT(1) NOT NULL DEFAULT 0
);
