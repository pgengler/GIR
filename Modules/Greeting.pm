package Modules::Greeting;

use strict;

my @hello;

BEGIN {
	# ways to say hello
	@hello = (
		'hello',
		'hi',
		'hey',
		'nihao',
		'喂!',
		'你好',
		'bonjour',
		'hola',
		'¡Oye!',
		'salut',
		'qué tal',
		'privet',
		"what's up"
	);
}

sub register
{
	GIR::Modules->register_action(qr/^\s*(h(ello|i( there)?|owdy|ey|ola)|salut|bonjour|niihau|que\s*tal)(\,|\s)?($GIR::Bot::config->{'nick'})?\s*$/, \&Modules::Greeting::process);
}

sub process
{
	my $message = shift;

	if (!$message->is_addressed && rand > 0.35) {
		# 65% chance of replying to a random greeting when not addressed
		return;
	}

	return $hello[int(rand(@hello))] . ', ' . $message->from;

}

1;
