package Modules::Access;

## TODO:
## - show access for other users
## - register
## - change password?

use strict;

sub register
{
	GIR::Modules::register_private('show access', \&Modules::Access::show_access);
	GIR::Modules::register_private('add access', \&Modules::Access::add_access);
	GIR::Modules::register_private('remove access', \&Modules::Access::remove_access);
}

sub show_access
{
	my $message = shift;

	my $user = $message->from;
	my $isSelf = 1;

	if ($message->message) {
		$user = $message->message;
		$isSelf = 0;
	}

	# Look up access for this user
	my $query = qq~
		SELECT name
		FROM access_permissions p
		LEFT JOIN access_user_permissions up ON up.permission_id = p.id
		WHERE up.user_id = (SELECT id FROM access_users WHERE nick = ?)
	~;
	my $statement = db()->query($query, $user);

	my @permissions;
	while (my $permission = $statement->fetch) {
		push @permissions, $permission->{'name'};
	}

	$user = $isSelf ? 'You' : $user;

	if (scalar(@permissions) > 0) {
		return sprintf('%s %s the following permissions: %s', $user, $isSelf ? 'have' : 'has', join(', ', @permissions));
	} else {
		return sprintf('%s do%s not have any special permissions.', $user, $isSelf ? '' : 'es');
	}
}

#######
## CHECK ACCESS
## Takes a nick, password, and access, and returns 1 if the user has that access (and a correct password).
## This function is intended to be called from other modules.
#######
sub check_access
{
	my ($user, $password, $access) = @_;

	# Look up user
	my $query = qq~
		SELECT id
		FROM access_users
		WHERE nick = ? AND password = ?
	~;
	my $user_info = db()->query($query, $user, $password)->fetch;

	unless ($user_info && $user_info->{'id'}) {
		GIR::Bot::debug("Modules::Access::check_access: User '%s' not found.", $user);
		return 0;
	}

	# Check for access
	$query = qq~
		SELECT up.permission_id
		FROM access_user_permissions up
		LEFT JOIN access_permissions p ON p.id = up.permission_id
		WHERE up.user_id = ? AND p.name = ?
	~;
	$access = db()->query($query, $user_info->{'id'}, $access)->fetch;

	if ($access && $access->{'permission_id'}) {
		return 1;
	}
	GIR::Bot::debug("Modules::Access::check_access: User %s doesn't have '%s' permission", $user_info->{'id'}, $access);
	return 0;
}

sub add_access
{
	my $message = shift;

	# Get the parts; syntax is <password> <user> <access>
	my $user = $message->from;
	my ($password, $target_user, $to_add) = split(/\s+/, $message->message, 3);

	my $allowed = check_access($user, $password, 'add_access');

	unless ($allowed) {
		return "You don't have permission to do that, $user!";
	}

	# Check if the access exists
	my $query = qq~
		SELECT id
		FROM access_permissions
		WHERE name = ?
	~;
	my $access = db()->query($query, $to_add)->fetch;

	# Add it if it doesn't
	unless ($access && $access->{'id'}) {
		$query = q~
			INSERT INTO access_permissions (name) VALUES (?) RETURNING id
		~;
		$access = db()->query($query, $to_add)->fetch('id')
	} else {
		$access = $access->{'id'};
	}

	# Look up user
	$query = qq~
		SELECT id
		FROM access_users
		WHERE nick = ?
	~;
	my $user_info = db()->query($query, $target_user)->fetch;

	unless ($user_info && $user_info->{'id'}) {
		return "$target_user isn't registered.";
	}

	# Check if user already has that access
	$query = qq~
		SELECT p.id
		FROM access_permissions p
		LEFT JOIN access_user_permissions up ON up.permission_id = p.id
		WHERE up.user_id = ? AND p.id = ?
	~;
	my $curr_access = db()->query($query, $user_info->{'id'}, $access)->fetch;

	if ($curr_access && $curr_access->{'id'}) {
		return "$target_user already has the permission '$to_add'";
	}

	# Add permission to user
	$query = qq~
		INSERT INTO access_user_permissions
		(user_id, permission_id)
		VALUES
		(?, ?)
	~;
	db()->query($query, $user_info->{'id'}, $access);

	return 'Permission added';
}

sub remove_access
{
	my $message = shift;

	# Get the parts; syntax is <password> <user> <access>
	my $user = $message->from;
	my ($password, $target_user, $to_remove) = split(/\s+/, $message->message, 3);

	my $allowed = check_access($user, $password, 'remove_access');

	unless ($allowed) {
		return "You don't have permission to do that, $user!";
	}

	# Look up target user
	my $query = qq~
		SELECT id
		FROM access_users
		WHERE nick = ?
	~;
	my $user_info = db()->query($query, $target_user)->fetch;

	unless ($user_info && $user_info->{'id'}) {
		return "$target_user isn't registered, $user";
	}

	# Look up permission
	$query = qq~
		SELECT p.id
		FROM access_permissions p
		LEFT JOIN access_user_permissions up ON up.permission_id = p.id
		WHERE p.name = ? AND up.user_id = ?
	~;
	my $permission = db()->query($query, $to_remove, $user_info->{'id'})->fetch;

	unless ($permission && $permission->{'id'}) {
		return "$target_user doesn't have that permission, $user";
	}

	# Remove the permission
	$query = qq~
		DELETE FROM access_user_permissions
		WHERE user_id = ? AND permission_id = ?
	~;
	db()->query($query, $user_info->{'id'}, $permission->{'id'});

	return 'Permission removed';
}

1;
