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

sub process()
{
	my ($who, $data) = @_;

	# Check if answers are loaded
	unless (@answers) {
		my $answer_file = $Bot::config->{'data_dir'} . '/8ball.txt';
		open(ANSWERS, $answer_file);
		while (<ANSWERS>) {
			chomp;
			push @answers, $_;
		}
	}

	if (@answers) {
		# Get a random response
		return $answers[rand(@answers)];
	}
}

sub help()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	return "'8ball <question>': Used a magic 8-ball to try to divine an answer to your question.";
}

1;
