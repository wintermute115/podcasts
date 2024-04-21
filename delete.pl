#!/usr/bin/perl -w

# Deletes podcasts that have already been listened to

use strict;
use File::Basename;
use Number::Bytes::Human;

chdir(dirname(__FILE__));
require("./locations.pl");

my $playlist = "/Playlists/Podcasts.m3u8";
my $bookmark_regex = qr/^>\d+;(\d+);\d+;\d+;(\d+);(?:\d+;)*(.+\.m3u8);/;
my $counter = 0;
my $deleted = 0;
my $size    = 0;
my $human = Number::Bytes::Human->new(round_style => 'round', precision => 2);
my $directory;
my %per_podcast;
my $key;
my $val;
my @keys;
my $max_len = 0;
my $len;
my $padding;
my @fail_list;

die ("A download is in progress; Please try again later.\n") if (-e($FileNames::lockfile));
die ("iPod not attached!\n") unless (-e($FileNames::ipodroot));
die ("No bookmark file found!") unless (-e($FileNames::ipodbookmark));
die ("No playlist file found!") unless (-e($FileNames::ipodplaylistfile));

open(my $bookmarks, "<", $FileNames::ipodbookmark);
while (my $bookmark = <$bookmarks>) {
	if ($bookmark =~ $bookmark_regex) {
		my $location = $1;
		my $found_playlist = $3;
		my $re = qr/$playlist$/;
		if ($found_playlist =~ $re) {
			open(my $filelist, "<", $FileNames::ipodplaylistfile);
			FILES:
			while (my $file = <$filelist>) {
				$file =~ s/[^[:print:]]//g;
				if (-e($FileNames::ipodroot . $file)) {
					$deleted++;
					$size += -s($FileNames::ipodroot . $file);
					print "Deleting " . $file . "\n";
					unlink($FileNames::ipodroot . $file);
					$directory = (split(/\//, $file))[2];
					if (exists($per_podcast{$directory})) {
						$per_podcast{$directory} ++;
					} else {
						$per_podcast{$directory} = 1;
					}
					if (length($directory) > $max_len) {
						$max_len = length($directory);
					}
				} else {
					push(@fail_list, $file);
				}
				$counter++;
				if ($counter == $location) {
					last FILES;
				}
			}
		}
	}
}
print $deleted . ($deleted == 1 ? " file " : " files " ) . "with a total size of " . ($size == 0 ? "0 bytes" : $human->format($size)) . " have been deleted\n";

#Show detailed breakdown
@keys = sort(keys(%per_podcast));
while (($key, $val) = each(@keys)) {
	$len = length($val);
	$padding = $max_len - $len;
	print "$val: " . (" " x $padding) . ("X" x $per_podcast{$val}) . "\n";
}

if (scalar @fail_list > 0) {
	print "The following files could not be located:\n";
	for my $failed(@fail_list) {
		print $failed . "\n";
	}
}

# Preventing warnings
my $a;
$a = $FileNames::lockfile;