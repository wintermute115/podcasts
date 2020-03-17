#!/usr/bin/perl -w

#Copies podcasts from their downloaded location on my computer to my iPod
#and puts them in the right place in the playlist.

use strict;
use Getopt::Long;
use File::Copy qw(cp);
use File::Copy::Recursive qw(dirmove);
use List::MoreUtils qw(any);

require("/home/ross/scripts/podcasts/log.pl");

my $mode = "x";
my @legal_modes = ("a", "i", "o");
my $help = 0;
my $result = GetOptions("mode=s" => \$mode, "help" => \$help);

if ($help)
{
	print "This script copies podcasts that have been downloaded onto my iPod.\n";
	print "\t-m  --mode  How to merge the new and existing playlists\n";
	print "\t            a - Put the new podcasts at the end of the existing\n";
	print "\t                list\n";
	print "\t            i - Put the new podcasts after the current file being\n";
	print "\t                listened to\n";
	print "\t            o - Delete the existing playlist, and replace it with\n";
	print "\t                the new one\n";
	print "\t-h  --help  Display this help text and exit\n";
	exit();
}

my $iPod = "/media/ross/iPodClassic";
my $computer = "/home/ross/Downloads/New Podcasts";
my $podcast_folder = "/Podcasts/";
my $playlist = "/Playlists/Podcasts.m3u8";
my $bookmarkfile = $iPod . "/.rockbox/most-recent.bmark";
my $lockfile = $computer . "/podcasts.lock";
my $bookmark_regex = qr/^>\d+;(\d+);\d+;\d+;(\d+);(?:\d+;)*(.+\.m3u8);/;

#Stop if we can't continue
die ("A download is in progress; Please try again later.\n") if (-e($lockfile));
die ("No podcasts to copy!\n") unless (-e($computer . $podcast_folder));
die ("iPod not attached!\n") unless (-e($iPod));
die ("A valid mode has not been set. Can be [a]ppend, [i]nsert or [o]verwrite.\n") unless (any {$_ eq $mode} @legal_modes);

#Copy the files over
my ($count_files, $count_dirs, $depth) = dirmove($computer . $podcast_folder, $iPod . $podcast_folder);
$count_files -= $count_dirs;
$count_dirs -= 1;
my $output = "$count_files episode" . ($count_files == 1 ? "" : "s") . " of $count_dirs podcast" . ($count_dirs == 1 ? "" : "s") . " copied over.\n";
print $output;

my $mode_print = ($mode eq "a" ? "Append" : ($mode eq "i" ? "Insert" : "Overwrite"));
writelog("$mode_print mode - " . $output, 1);

#Deal with the playlist;
if ($mode eq "i")
{
  #Find out where we've gotten to so far, and insert at that point.
  my $found = 0;
  open(my $bookmarks, "<", $bookmarkfile) or die ("Cannot find bookmark file - $!");
  while (my $bookmark = <$bookmarks>)
  {
    if ($bookmark =~ $bookmark_regex)
    {
      my $location = $1;
      my $time = $2;
      my $found_playlist = $3;
      my $re = qr/$playlist$/;
      if ($found_playlist =~ $re)
      {
        #Read in the playlist from the computer
        $found = 1;
        open (my $playlist_handle, "<", $computer . $playlist);
        my @new_playlist = <$playlist_handle>;
        my $new_playlist = join ("", @new_playlist);
        close($playlist_handle);
        unless ($time < 5000) # 5 seconds
        {
          #If we're right at the beginning of a track, add the new files before, rather than after.
          $location += 1;
        }
        my $count = 0;
        my $playlist_contents = "";
        open($playlist_handle, "<", $iPod . $playlist);
        while (my $line = <$playlist_handle>)
        {
          if ($count == $location)
          {
            #Insert new items here
            $playlist_contents .= $new_playlist;
          }
          $count++;
          $playlist_contents .= $line;
        }
        close($playlist_handle);
        #Write everything back to the iPod
        open($playlist_handle, ">", $iPod . $playlist);
        print $playlist_handle $playlist_contents;
        last; #Don't check any more playlists after this
      }
    }
  }
  close($bookmarks);
  if (!$found)
  {
  	writelog("Cannot read playist from bookmark file");
    die("Cannot read playist from bookmark file");
  }
}
else
{
  #Back up the old playlist, in case we overwrote by accident
  cp($iPod . $playlist, $iPod . $playlist . ".old") if ($mode eq "o");
  #Either append or overwite the playlist
  my $write_mode = ($mode eq "o" ? ">" : ">>");
  #Read from the computer
  open(my $read_handle, "<", $computer . $playlist) or die ("cannot open local playlist - $!");
  my $playlist_contents = join("", <$read_handle>);
  close($read_handle);
  #Write to the iPod
  open(my $write_handle, $write_mode, $iPod . $playlist) or die ("cannot open iPod playlist - $!");
  print $write_handle $playlist_contents;
  close($write_handle);
}
#Wipe out the temporary playlist
open (my $wiper, ">", $computer . $playlist);
print $wiper "";
close($wiper);
print "Playlist written\n";

