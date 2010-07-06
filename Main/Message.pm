package Message;

use strict;

use constant {
	false => 0,
	true  => 1
};

#######
## CONSTRUCTOR
#######
## Parameters:
##   Accepts a Net::IRC::Event object for a public or private message.
##
## Return value:
##   Returns a new instance of the Message class.
#######
sub new()
{
	my ($class, $event) = @_;

	my $self = {
		'_nick'      => $event->{'nick'},
		'_where'     => ($event->{'type'} eq 'public') ? $event->{'to'}[0] : $event->{'nick'},
		'_raw'       => $event->{'args'}[0],
		'_host'      => $event->{'host'},
		'_fullhost'  => $event->{'from'},
		'_parsed'    => undef,
		'_addressed' => false,
		'_public'    => ($event->{'type'} eq 'public'),
	};

	bless $self, $class;

	$self->_parse();

	return $self;
}

#######
## GET PARSED MESSAGE
#######
## Parameters:
##   NONE
##
## Return value:
##   The message, with any bot addressing removed.
#######
sub message()
{
	my $self = shift;

	return $self->{'_parsed'} || $self->raw();
}

#######
## GET RAW MESSAGE
#######
## Parameters:
##   NONE
##
## Return value:
##   Returns the raw message with no parsing done.
#######
sub raw()
{
	my $self = shift;

	return $self->{'_raw'};
}

#######
## GET MESSAGE SENDER
#######
## Parameters:
##   NONE
##
## Return value:
##   Returns the nickname of the user who originated the message.
#######
sub from()
{
	my $self = shift;

	return $self->{'_nick'};
}

#######
## GET MESSAGE SENDER HOST
#######
## Parameters:
##   NONE
##
## Return value:
##   Returns the host of the user who originated the message.
#######
sub host()
{
	my $self = shift;

	return $self->{'_host'};
}

#######
## GET MESSAGE SENDER INFORMATION
#######
## Parameters:
##   NONE
##
## Return value:
##   Returns the nickname, username, and host of the user who originated
##   the message, in the form <nick>!<user>@<host>
#######
sub fullhost()
{
	my $self = shift;

	return $self->{'_fullhost'};
}

#######
## GET MESSAGE LOCATION
#######
## Parameters:
##   NONE
##
## Return value:
##   Returns the origin location for the message. For public messages, this is
##     the name of the channel; for private messages, it is the nickname of
##     the sender.
#######
sub where()
{
	my $self = shift;

	return $self->{'_where'};
}

#######
## IS MESSAGE ADDRESSED TO BOT?
#######
## Parameters:
##    NONE
##
## Return value:
##   If the message was addressed to the bot, returns true.
##   Otherwiese, returns false.
#######
sub is_addressed()
{
	my $self = shift;

	return $self->{'_addressed'};
}

#######
## IS MESSAGE PUBLIC?
#######
## Parameters:
##    NONE
##
## Return value:
##   If the message originated in a channel, returns true.
##   Otherwise, returns false.
#######
sub is_public()
{
	my $self = shift;

	return $self->{'_public'};
}

#######
## IS MESSAGE EXPLICITLY FOR THE BOT?
#######
## Parameters:
##    NONE
##
## Return value:
##   If the message was addressed to the bot, or was a private message,
##     returns true.
##   Otherwise, returns false.
#######
sub is_explicit()
{
	my $self = shift;

	if ($self->{'_addressed'} || !$self->is_public()) {
		return true;
	}
	return false;
}

##############
#### INTERNAL METHODS
##############

#######
## PARSE MESSAGE
######
## Parameters:
##   NONE
##
## Return value:
##   NONE
#######
## This method takes the raw message ($self->{'_raw'}) and checks if it was
## addressed to the bot. If it was, sets $self->{'_addressed'} to 'true' and
## stores the content of the message in $self->{'_parsed'}.
## This method also checks if the message originated in a channel, and if so,
## sets $self->{'_public'} to 'true'.
#######
sub _parse()
{
	my $self = shift;

	if ($self->{'_raw'} =~ /^\s*$Bot::config->{'nick'}(\,|\:|\s)\s*(.+)$/i) {
		$self->{'_addressed'} = true;
		$self->{'_parsed'}    = $2;
	} elsif ($self->{'_raw'} =~ /(.+?)(\,|\:|\s+)\s*$Bot::config->{'nick'}(\.|\?|\!)?\s*$/i) {
		$self->{'_addressed'} = true;
		$self->{'_parsed'}    = $1;
	}
}

1;
