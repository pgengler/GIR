package RuntimeLoader;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use Symbol;
use File::Spec;

##############

#######
## CONSTRUCTOR
#######
## Initialize a new instance of a RuntimeLoader object.
##
## Parameters:
##   $name
##   - the name of the module to load at runtime.
#######
sub new()
{
	my ($class, $name) = @_;

	my $self = {
		'_class' => $name,
		'_path'  => [ ],
		'_obj'   => undef
	};

	bless $self, $class;

	return $self;
}

#######
## ADD SEARCH PATH(S)
######
## Add a path or paths to @INC.
######
## Parameters:
##   @paths
##   - a list of paths to be added to @INC
##
## Return value:
##   NONE
#######
sub add_path()
{
	my ($self, @paths) = @_;

	foreach my $path (@paths) {
		push @{ $self->{'_path'} }, $path
	}
}

#######
## LOAD MODULE
#######
## Load the specified module.
#######
## Parameters:
##   NONE
##
## Return Value:
##   Returns a new instance of the specified object if successful. On failure,
##   returns 'undef' and $@ contains the error.
#######
sub load()
{
	my $self = shift;

	unless ($self->{'_class'}) {
		return;
	}

	my $file = File::Spec->catfile( split '::', $self->{'_class'} ) . '.pm';

	# Add custom paths to @INC
	unshift @INC, @{ $self->{'_path'} };

	eval qq~
		require '$file';
		\$self->{'_obj'} = $self->{'_class'}->new();
	~;

	# Remove custom paths from @INC
	$self->_clean_inc();

	return $self->{'_obj'};
}

#######
## UNLOAD MODULE
#######
## Unload the current module.
#######
## Parameters:
##   NONE
##
## Return Value:
##   NONE
#######
sub unload()
{
	my $self = shift;

	return if $self->{'_class'} eq __PACKAGE__;

	Symbol::delete_package($self->{'_class'});
	my $file = File::Spec->catfile( split '::', $self->{'_class'} ) . '.pm';
	delete $INC{$file} if exists $INC{$file};

	return 1;
}

#######
## CLEAN @INC
#######
## Remove custom search paths from @INC
#######
## Parameters:
##   NONE
##
## Return Value:
##   NONE
#######
sub _clean_inc()
{
	my $self = shift;

	foreach my $path (@{ $self->{'_path'} }) {
		for (my $i = 0; $i < @INC; $i++) {
			if ($path eq $INC[$i]) {
				splice(@INC, $i, 1);
			}
		}
	}
}

1;
