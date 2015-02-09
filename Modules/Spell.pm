package Modules::Spell;

use strict;

sub register
{
	my $self = shift;

	GIR::Modules->register_action('spell', \&process);
	GIR::Modules->register_help('spell', \&help);
}

sub process
{
	my $message = shift;

	my $data = $message->message;
	$data =~ s/^\s+//;
	$data =~ s/\s+$//;

	return "$data looks funny" unless $data =~ /^\w+$/;

	my @tr = `echo $data | ispell -a -S`;

	my $result = '';

	if (grep /^\*/, @tr) {
		$result = "'$data' may be spelled correctly";
	} else {
		@tr = grep /^\s*&/, @tr;
		chomp $tr[0];
		my ($something, $word, $count1, $count2, @rest) = split(/\ |\,\ /,$tr[0]);
		$result = "Possible spellings for $data: @rest";
		if (scalar(@rest) == 0) {
			$result = "I can't find alternate spellings for '$data'";
		}
	}
	return $result;
}

sub help
{
	my $message = shift;

	return "'spell <word>': Given a possibly-misspelled word; uses ispell to try to find the right spelling.";
}

1;
