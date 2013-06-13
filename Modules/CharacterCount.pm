package Modules::CharacterCount;

use strict;

sub register
{
  GIR::Modules::register_action('charcount', \&count_chars);
}

sub count_chars($)
{
  my ($message) = @_;

  return length($message->message);
}

1;
