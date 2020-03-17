#!/usr/bin/perl -w

# Deletes podcasts that have already been listened to

use Number::Bytes::Human;
use strict;

my $iPod = "/media/ross/iPodClassic";
my $computer = "/home/ross/Downloads/New Podcasts";
my $playlist = "/Playlists/Podcasts.m3u8";
my $bookmarkfile = $iPod . "/.rockbox/most-recent.bmark";
my $bookmark_regex = qr/^>\d+;(\d+);\d+;\d+;(\d+);(?:\d+;)*(.+\.m3u8);/;
my $lockfile = $computer . "/podcasts.lock";
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

die ("A download is in progress; Please try again later.\n") if (-e($lockfile));
die ("iPod not attached!\n") unless (-e($iPod));
die ("No bookmark file found!") unless (-e($bookmarkfile));
die ("No playlist file found!") unless (-e($iPod . $playlist));

open(my $bookmarks, "<", $bookmarkfile);
while (my $bookmark = <$bookmarks>) {
	if ($bookmark =~ $bookmark_regex) {
		my $location = $1;
		my $found_playlist = $3;
		my $re = qr/$playlist$/;
		if ($found_playlist =~ $re) {
			open(my $filelist, "<", $iPod . $playlist);
			FILES:
			while (my $file = <$filelist>) {
				chomp($file);
				if (-e($iPod . $file)) {
					$deleted++;
					$size += -s($iPod . $file);
					# print "Deleting " . $iPod . $file . "\n";
					print "Deleting " . $file . "\n";
					unlink($iPod . $file);
					$directory = (split(/\//, $file))[2];
					if (exists($per_podcast{$directory})) {
						$per_podcast{$directory} ++;
					} else {
						$per_podcast{$directory} = 1;
					}
					if (length($directory) > $max_len) {
						$max_len = length($directory);
					}
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
	print "$val: " . (" " x $padding) . $per_podcast{$val} . "\n";
}
