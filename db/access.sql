CREATE TABLE access_permissions (
	id INT NOT NULL auto_increment,
	name VARCHAR(128) NOT NULL,
	PRIMARY KEY(id)
);

INSERT INTO access_permissions (name) VALUES ('add_access');
INSERT INTO access_permissions (name) VALUES ('remove_access');
INSERT INTO access_permissions (name) VALUES ('ignore');
INSERT INTO access_permissions (name) VALUES ('lock');
INSERT INTO access_permissions (name) VALUES ('unlock');
INSERT INTO access_permissions (name) VALUES ('nick');
INSERT INTO access_permissions (name) VALUES ('op');
INSERT INTO access_permissions (name) VALUES ('deop');
INSERT INTO access_permissions (name) VALUES ('kick');

CREATE TABLE access_user_permissions (
	user_id INT NOT NULL,
	permission_id INT NOT NULL
);

CREATE TABLE access_users (
	id INT NOT NULL auto_increment,
	nick VARCHAR(128) NOT NULL,
	password VARCHAR(128) NOT NULL,
	PRIMARY KEY(id)
);
	

