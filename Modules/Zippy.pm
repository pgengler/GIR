package Modules::Zippy;

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

	&Modules::register_action('yow', \&Modules::Zippy::zippy);
	&Modules::register_help('yow', \&Modules::Zippy::help);
}

sub zippy($)
{
	my $message = shift;

	open(my $zippy, '-|', '/usr/games/fortune zippy') or do { Bot::error("Modules::Zippy couldn't launch fortune: %s", $!); return undef; };
	my $yow;
	while (<$zippy>) {
		$yow .= $_;
	}
	close($zippy);
	$yow =~ s/\n/ /g;

	return $yow;	
}

sub help($)
{
	my $message = shift;

	return "yow: prints a random Zippy the Pinhead message";
}

1;
