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
}

sub zippy()
{
	open(ZIPPY, "/usr/games/fortune zippy |");
	my $yow;
	while (<ZIPPY>) {
		$yow .= $_;
	}
	close(ZIPPY);
	$yow =~ s/\n/ /g;

	return $yow;	
}

1;
