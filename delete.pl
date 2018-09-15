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

die ("A download is in progess; Please try again later.\n") if (-e($lockfile));
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
					print "Deleting " . $iPod . $file . "\n";
					unlink($iPod . $file);
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
