CREATE TYPE relation AS enum ('is', 'are');
CREATE TABLE infobot (
	phrase VARCHAR(255) NOT NULL,
	relates relation NOT NULL DEFAULT 'is',
	value TEXT NULL,
	locked BOOLEAN DEFAULT false
);
