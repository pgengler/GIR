package Modules::Eightball;

use strict;

my @answers;

sub new()
{
	my $pkg = shift;
	my $obj = { };
	bless $obj, $pkg;
	return $obj;
}

sub register()
{
	my $this = shift;

	&Modules::register_action('8ball', \&Modules::Eightball::process);
	&Modules::register_action('8-ball', \&Modules::Eightball::process);

	&Modules::register_help('8ball', \&Modules::Eightball::help);
}

sub process($)
{
	my $message = shift;

	# Check if answers are loaded
	unless (@answers) {
		my $answer_file = $Bot::config->{'data_dir'} . '/8ball.txt';
		open(my $fh, '<', $answer_file) or do { Bot::status("ERROR: Modules::Eightball can't read 8ball.txt: %s", $!); return undef };
		while (<$fh>) {
			chomp;
			push @answers, $_;
		}
		close($fh);
	}

	if (@answers) {
		# Get a random response
		return $answers[rand(@answers)];
	}
}

sub help($)
{
	my $message = shift;

	return "'8ball <question>': Used a magic 8-ball to try to divine an answer to your question.";
}

1;
