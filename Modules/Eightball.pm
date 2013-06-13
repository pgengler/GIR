package Modules::Eightball;

use strict;
use feature 'state';

sub register
{
	GIR::Modules::register_action('8ball', \&Modules::Eightball::process);
	GIR::Modules::register_action('8-ball', \&Modules::Eightball::process);

	GIR::Modules::register_help('8ball', \&Modules::Eightball::help);
}

sub process($)
{
	my $message = shift;

	my @responses = load_responses();

	# Get a random response
	return $responses[rand(@responses)];
}

sub help($)
{
	my $message = shift;

	return "'8ball <question>': Used a magic 8-ball to try to divine an answer to your question.";
}

sub load_responses()
{
	state $data_position = tell DATA;

	my @storage;

	while (my $line = <DATA>) {
		chomp $line;
		push @storage, $line;
	}

	seek DATA, $data_position, 0;

	return @storage;
}

1;

__DATA__
Outlook Not So Good
My Reply Is No
Don't Count On It
You May Rely On It
Ask Again Later
Most Likely
Cannot Predict Now
Yes
Yes Definitely
Better Not Tell You Now
It Is Certain
Very Doubtful
It Is Decidedly So
Concentrate and Ask Again
Signs Point to Yes
My Sources Say No
Without a Doubt
Reply Hazy, Try Again
As I See It, Yes
NOT
What do YOU think
Obviously
Ask me if I care
Yeah, and I'm the Pope
That's ridiculous
Who cares
Forget about it
You wish
Yeah, right
Sure
Get a clue
In your dreams
Oh, please
Whatever
As if
You've got to be kidding
Dumb question.  Ask another
Not a chance
Outlook Sucks
THIS SPACE FOR RENT
Bugger Off
How appropriate, you fight like a cow
Eat more cheese, then ask again
When hell freezes over
