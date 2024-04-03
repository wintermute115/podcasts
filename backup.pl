#!/usr/bin/perl -w

use strict;
use File::Copy qw(cp);
use File::Rsync;

my $target = "/home/ross/Documents/ipod/";

sub copy_dir
{
	my $source = $_[0];
	my $dest = $target . $_[1];
	my $delete = $_[2];

	my $sync = File::Rsync->new(src=>$source, dest=>$dest, delete=>$delete, archive=>1);

	$sync->exec();


}

sub copy_file
{
	my $source = $_[0];
	my $dest = $target . $_[1];
	cp($source, $dest);

}


copy_dir("/media/ross/iPodClassic/Music/", "Music", 1);