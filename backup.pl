#!/usr/bin/perl -w

use strict;
use File::Basename;
use File::Copy qw(cp);
use File::Rsync;

chdir(dirname(__FILE__));
require("./locations.pl");

sub copy_dir
{
	my $source = $_[0];
	my $dest = $FileNames::backup . $_[1];
	my $delete = $_[2];

	print $source . "\n";
	print $dest . "\n";
	my $sync = File::Rsync->new(src=>$source, dest=>$dest, delete=>$delete, archive=>1);

	$sync->exec();


}

sub copy_file
{
	my $source = $_[0];
	my $dest = $FileNames::backup . $_[1];

	print $source . "\n";
	print $dest . "\n";
	cp($source, $dest);

}
