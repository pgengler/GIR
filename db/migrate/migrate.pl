#!/usr/bin/perl

use strict;
use warnings;

use Migrate qw/ copy_table /;

copy_table('access_users',            [ qw/ id nick password / ]);
copy_table('access_user_permissions', [ qw/ user_id permission_id / ]);
copy_table('bashquotes', [ qw/ id quote / ]);
copy_table('infobot',    [ qw/ phrase relates value locked / ]);
copy_table('karma',      [ qw/ name karma / ]);
copy_table('qdbquotes',  [ qw/ id quote / ]);
copy_table('seen',       [ qw/ who what where when / ]);
copy_table('words',      [ qw/ prev this next / ]);
