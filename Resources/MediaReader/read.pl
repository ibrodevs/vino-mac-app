#!/usr/bin/perl
use strict;
use warnings;
use DynaLoader;
my $path = shift @ARGV or die "Missing media reader library\n";
my $handle = DynaLoader::dl_load_file($path, 0) or die DynaLoader::dl_error();
my $symbol = DynaLoader::dl_find_symbol($handle, 'vino_read') or die DynaLoader::dl_error();
DynaLoader::dl_install_xsub('main::read_session', $symbol);
read_session();
