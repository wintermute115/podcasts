#!/usr/bin/perl

#Automatically downloads podcasts to my computer so they
#can be copied to my iPod.

#Runs as a cron job every hour.

use strict;
use Data::Dumper;
use File::Basename;
use Getopt::Long;
use IO::Uncompress::Gunzip qw(gunzip);
use MP3::Info;
use MP3::Tag;
use Net::Curl::Easy qw(:constants);
use Net::MySQL;
use Number::Format;
use String::Util qw(trim);
use Term::ANSIColor;
use Time::Local qw(timelocal_modern);
use Try;
use URI::Escape;
use XML::RSS;

# MySQL functions
require("/home/ross/scripts/podcasts/connect.pl");
# Logging functions
require("/home/ross/scripts/podcasts/log.pl");
# Backup
require("/home/ross/scripts/podcasts/backup.pl");

my %playlist;
my $updated_config = "";
my $final_data;
my $total_size;

my $root = "/home/ross/Downloads/New_Podcasts/";
#my $root = "/home/ross/Dropbox/Podcasts/";

my $basedir = $root . "Podcasts";
my $playlistdir = $root . "Playlists";
my $lockfile = $root . "podcasts.lock";
my $archive = $root . "archive/";

binmode STDOUT, ":utf8";

# Commandline options
my $list = "";
my $add;
my $delete;
my $name = "";
my $url = "";
my $toggle = "";
my $podcast = "";
my $caller = "user";
my $move = "";
my $just_playlist;
my $year_limit;
my $result = GetOptions("list=s"        => \$list,
                        "add"           => \$add,
                        "name=s"        => \$name,
                        "url=s"         => \$url,
                        "caller=s"      => \$caller,
                        "podcast=s"     => \$podcast,
                        "toggle=s"      => \$toggle,
                        "move=s"        => \$move,
                        "just_playlist" => \$just_playlist,
                        "x"             => \$delete,
                        "year_limit"    => \$year_limit);

# MySQL object
my $conn = mysql_connect();

if ($list ne "")
{
	#Provide a list of feeds in the database
	#List can be in order of [d]ate, [a]lphabet or [i]d
	my $order = "name";
	if ($list eq "d") {
		$order = "date";
	} elsif ($list eq "i") {
		$order = "id";
	}
	my $rs = get_podcast_rows($conn, $order);
	my $header_row = $rs->each;
	my $id_len = $header_row->[0];
	my $name_len = $header_row->[1];
	print color 'bold';
	print "ID" . " " x ($id_len - 1);
	print "Title" . " " x ($name_len - 4);
	print "Last Recieved\n";
	print color 'reset';
	while (my $row = $rs->each)
	{
		if ($row->[2] eq '1')
		{
			print color 'grey8';
		}
		print $row->[0] . " " x (($id_len + 1) - length($row->[0]));
		print $row->[1] . " " x (($name_len + 1) - length($row->[1]));
		print $row->[3] . "   ";
		print "\n";
		print color 'reset';
	}
	exit;
}

if ($delete) {
	my $dir = dirname(__FILE__);
	exec($dir . "/delete.pl");
	exit;
}

if ($move ne "") {
	my $dir = dirname(__FILE__);
	exec($dir . "/movepods.pl -m $move");
	exit;
}

if ($add) {
	# Add a new feed to the list
	if ($name ne "" && $url ne "") {
		$toggle = ($toggle eq "off" ? "off" : "on");
		my $rs = add_podcast($conn, $name, $url, $toggle);
		print "Podcast $name [$url] has been added\n";
		my $logmsg = "Podcast \"$name\" at $url has been added" . ($toggle eq "off" ? " (currently disabled)" : "");
		writelog($logmsg);
	} else {
		print "--You must set a name and a url to add a podcast\n";
	}
	exit;
}

if ($toggle ne "" && $podcast ne "") {
	# Toggle a podcast on or off
	if ($toggle eq 'on' || $toggle eq 'off') {
			my $rs = toggle_podcast($conn, $podcast, $toggle);
			my $row = $rs->each;
			my $id = $row->[0];
			my $name = $row->[1];
			my $skip = $row->[2];
			print "Podcast '$name' is now ";
			print ($skip eq '1' ? "off" : "on");
			writelog("Podcast '$name' has been " . ($skip eq '1' ? "disabled" : "enabled"));
			print "\n";
	} else {
		print "--toggle must be 'on' or 'off'\n";
	}
	exit;
}

if (-e($lockfile)) {
	my $lockfile_created = (stat($lockfile))[9];
	if ($caller eq "boot" || time() - $lockfile_created > 7200) {
		#Didn't clean up the lockfile on shutdown
		unlink($lockfile);
	}
}

# cURL object
my $curl = Net::Curl::Easy->new;

#Check that we can connect to the network
try
{
	$curl->pushopt(CURLOPT_HTTPHEADER, ["User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:30.0) Gecko/20100101 Firefox/30.0"]);
	$curl->setopt(CURLOPT_PROGRESSFUNCTION, \&no_progress);
	$curl->setopt(CURLOPT_NOPROGRESS, 0);
	$curl->setopt(CURLOPT_FOLLOWLOCATION, 1);
	$curl->setopt(CURLOPT_CONNECT_ONLY, 1);
	$curl->setopt(CURLOPT_FAILONERROR, 1);
	$curl->setopt(CURLOPT_URL, "http://www.google.com");
	$curl->perform();
}
catch
{
	die ("Cannot connect to the Internet\n");
}


# Make sure we're not already downloading podcasts
die("Another download is currently in progress; Please try again later\n") if (-e($lockfile));
open(my $lockhandle, ">", $lockfile) or die ("Cannot create lockfile: $!");
close($lockhandle);

my $rs = get_podcast_list($conn, $podcast);


# Number formatter
my $formatter = new Number::Format(-thousands_sep   => ',',
                                   -decimal_digits  => 0,
                                   -kilo_suffix     => 'Kb');

FEED: # Step through the feeds
while (my $row = $rs->each)
{
	my $id = $row->[0];
	my $name = $row->[1];
	my $feedsrc = $row->[2];
	my $timestamp = $row->[3];

 		print "$name";
 		#parse date
		my ($date, $time) = split(/ /, $timestamp);
		my ($year, $mon, $day) = split(/-/, $date);
		my ($hour, $min, $sec) = split(/:/, $time);
		my $last_download = timelocal_modern($sec, $min, $hour, $day, $mon - 1, $year);
		my $download_limit = timelocal_modern(localtime());
		if ($year_limit)
		{
			my $download_limit = timelocal_modern($sec, $min, $hour, $day, $mon -1, $year + 1);
		}
		my $feed;
		my $broken = 0;
		mkdir($archive) unless (-d($archive));
		my $filename = $archive . $name . ".rss";
		# set up cURL options
		try
		{
			$curl->pushopt(CURLOPT_HTTPHEADER, ["User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:30.0) Gecko/20100101 Firefox/30.0"]);
			$curl->setopt(CURLOPT_PROGRESSFUNCTION, \&no_progress);
			$curl->setopt(CURLOPT_NOPROGRESS, 0);
			$curl->setopt(CURLOPT_FOLLOWLOCATION, 1);
			$curl->setopt(CURLOPT_CONNECT_ONLY, 0);
			$curl->setopt(CURLOPT_URL, $feedsrc);
			$curl->setopt(CURLOPT_WRITEDATA, \$feed);
			$curl->perform();
		}
		catch
		{
			$broken = 1; #putting next in here complains that it's exiting a subroutine
		}
		if (!defined($feed))
		{
			$broken = 1;
		}
		if ($broken)
		{
			print " -- Unreadable\n";
			open (my $archive_handle, ">>", $filename);
			binmode $archive_handle, ":utf8";
			print $archive_handle "Could not access RSS file: " . gettime() . "\n";
			close ($archive_handle);
			next FEED;
		}

		my $parser = XML::RSS->new();
		if (substr($feed, 0, 3) eq chr(0x1f) . chr(0x8b) . chr(0x08)) # magic number for GZip files
		{
			my $unzipped_feed;
			gunzip \$feed => \$unzipped_feed;
			$feed = $unzipped_feed;
		}
		$feed =~ s/\x{feff}//g; # strip out wide spaces
		# Write out the RSS file, in case we need to do diagnostics
		open (my $archive_handle, ">", $filename);
		binmode $archive_handle, ":utf8";
		print $archive_handle $feed . "\n";
		close ($archive_handle);
		if (substr($feed, 0, 5) ne "<?xml" && substr($feed, 3, 5) ne "<?xml") #SGU feeds have three odd characters before the opening tag
		{
			# my $logstring = "Error reading \"$name\" for RSS feed [$feedsrc] ::: " . substr($feed, 0, 10) . " :::";
			# for my $i (0 .. 9)
			# {
			# 	#Log the first 10 bytes so we can identify the compression type, and deal with it in the future.
			# 	my $byte = sprintf("%02x", ord(substr($feed, $i, 1)));
			# 	$logstring .= " " . $byte;
			# }
			# print $logstring;
			print " -- Unreadable\n";
			next FEED;
 		}
		print "\n";
		try
		{
			$parser->parse($feed);
		}
		catch
		{
			#Go on the the next if this one is unreadable
			$broken = 1; #putting next in here complains that it's exiting a subroutine
		}
		if ($broken) {
			print "\n";
			next FEED;
		}
		my $new_last_download = $last_download;
		foreach my $item (@{$parser->{'items'}}) {
			#Check each item in the feed
			my $title = $item->{'title'};
			$title =~ s/\n//g; #Strip out newlines
			$title =~ s/\x{2013}/-/g; #Convert long hyphens to ASCII equivalent
			my $summary = $item->{'http://www.itunes.com/dtds/podcast-1.0.dtd'}->{'subtitle'};
			$summary = trim($summary);
			$summary =~ s/\n/ /g;
			$summary =~ s/\s+$/ /g;
			if ($summary ne '') {
				$summary = "\n" . (' ' x 23) . $summary;
			}
			my $pubdate = parse_date($item->{'pubDate'});
			my $type = $item->{'enclosure'}->{'type'};
			my $url = $item->{'enclosure'}->{'url'};
			$url = (defined($url) ? $url : "");
			$url =~ /.([^\/]*\.(mp3|m4a))(?!.*(mp3|m4a))/; #separate out the filename
			my $fname = uri_unescape($1);
			if (index($fname, "/") != -1) {
				#Strip out other URI parts
				$fname =~ /^.*\/(.*)$/;
				$fname = $1;
			}

			next if ($pubdate <= $last_download); #If we've cycled through all the newer ones, stop now.

			if (defined($type) && $type =~ /^audio\//i && (!$year_limit || $pubdate < $download_limit)) {
				#Only download audiofiles that are before our defined end time (either now or a year after the last download)
				$new_last_download = ($pubdate > $new_last_download ? $pubdate : $new_last_download);
				print color 'bold';
				mkdir($basedir) unless (-d($basedir));
				mkdir("$basedir/$name") unless (-d("$basedir/$name"));
				if (!$just_playlist) {
					$fname = get_savename ($fname);
					my $fullname = "$basedir/$name/$fname";
					# Write to the log
					my $note = "Downloading \"$title\" [$fname]";
					print $note . (length($note) == 80 ? "" : "\n"); #Adding a newline after an 80-char line results in a blank line
					my $final_data;
					$curl->pushopt(CURLOPT_HTTPHEADER, ["User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:30.0) Gecko/20100101 Firefox/30.0"]);
					$curl->setopt(CURLOPT_NOPROGRESS, 0);
					$curl->setopt(CURLOPT_PROGRESSFUNCTION, \&progress);
					$curl->setopt(CURLOPT_URL, $url);
					$curl->setopt(CURLOPT_WRITEDATA, \$final_data);
					$curl->perform();
					my $size = length($final_data);
					printf("%-75s\n", $formatter->format_bytes($size, unit => 'K'));
					# write out the podcast to a file
					open(my $write_handle, ">", $fullname);
					binmode($write_handle);
					print $write_handle $final_data;
					close($write_handle);
					check_title($fullname, $title);
					my $duration = get_duration($fullname);
					# Write to the log
					writelog($note . " - [" . $duration . "]" . $summary );
				} else {
					my $note = "Building playlist for \"$title\" [$fname]";
					print $note . (length($note) == 80 ? "" : "\n"); #Adding a newline after an 80-char line results in a blank line
				}
				#Track the file for the playlist
				$playlist{$pubdate . $title} = "/Podcasts/$name/$fname";
				print color 'reset';
			}

		}
		# Update the last downloaded time in the database
		my ($new_sec, $new_min, $new_hr, $new_day, $new_mon, $new_year, $new_wday, $new_yday, $new_isdst) = localtime($new_last_download);
		my $new_date = ($new_year + 1900) . "-" . sprintf("%0*d", 2, $new_mon + 1) . "-" . sprintf("%0*d", 2, $new_day) . " " . sprintf("%0*d", 2, $new_hr) . ":" . sprintf("%0*d", 2, $new_min) . ":" . sprintf("%0*d", 2, $new_sec);
		write_to_database($conn, $id, $new_date);
}
my $count = keys(%playlist);
print color 'bold';
print "$count podcast" . ($count == 1 ? "" : "s") . " downloaded\n\n";
print color 'reset';
if ($count)
{
	#Write out the playlist
	print "Writing Playlist\n";
	mkdir($playlistdir) unless (-d($playlistdir));
	open(my $playlist_handle, ">>", "$playlistdir/Podcasts.m3u8");
	my @keys = sort({$a cmp $b} keys(%playlist)); #Sorted by date
	foreach my $key (@keys)
	{
		print $playlist_handle $playlist{$key} . "\n";
	}
	close($playlist_handle);
	dump_database();
}
unlink($lockfile) or die ("Cannot delete lockfile: $!");

close_connection($conn);

#Copy new podcasts to the backup without deleting existing ones
copy_dir($basedir . "/", "Podcasts", 0);

## Helper functions start here

sub parse_date
{
	my $datestr = $_[0];
	my %months = ("jan" => "00",
	              "feb" => "01",
	              "mar" => "02",
	              "apr" => "03",
	              "may" => "04",
	              "jun" => "05",
	              "jul" => "06",
	              "aug" => "07",
	              "sep" => "08",
	              "oct" => "09",
	              "nov" => "10",
	              "dec" => "11");
	$datestr =~ /(\d{1,2}) ([[:alpha:]]{3})[[:alpha:]]* (\d{4}) (\d{2}):(\d{2}):(\d{2})/;
	my $day = $1;
	my $mon = $months{lc($2)};
	my $year = $3;
	my $hour = $4;
	my $min = $5;
	my $sec = $6;
	return (timelocal_modern($sec, $min, $hour, $day, $mon, $year));
}

sub get_savename {
	# Gives every file a (hopefully) unique four-character suffix to aviod collisions if multiple podcasts in a feed have the same filename
	my $fname = $_[0];
	my $base;
	my $ext;
	my $save_name;

	($base, $ext) = $fname =~ /(.*)\.(.*?)$/;
	# ($base, $ext) = split(/\.([^\.]+)$/, $fname);

	my @alphabet = ('0' ..'9', 'A' .. 'Z', 'a' .. 'z');
	my $suffix = join '' => map($alphabet[rand(@alphabet)], 1 .. 4);

	$save_name = $base . '-'. $suffix . '.' . $ext;

	return $save_name;
}

sub get_duration {
	my $file = $_[0];
	my $duration = "";
	my $mp3 = MP3::Tag->new($file);
	my $mins = $mp3->total_mins();
	my $secs = $mp3->leftover_secs();
	if (length($secs) == 1) {
		$secs = "0" . $secs;
	}
	if ($mins > 59) {
		my $hours = int($mins / 60);
		$mins %= 60;
		if (length($mins) == 1) {
			$mins = "0" . $mins;
		}
		$duration = $hours . ":" . $mins . ":" . $secs;
	} else {
		$duration = $mins . ":" . $secs;
	}
	return $duration;
}

sub check_title {
	# Makes sure that each file has a title set in the ID3 tags
	my $file = $_[0];
	my $title = $_[1];

	my $mp3 = MP3::Tag->new($file);
	my $current_title = $mp3->select_id3v2_frame_by_descr("TIT2");
	if($current_title eq "") {
		$mp3->select_id3v2_frame_by_descr("TIT2", $title);
		$mp3->config(write_v24 => 1);
		$mp3->update_tags();
	}
	return 0;
}

sub progress
{
	my ($easy, $dltotal, $dlnow) = @_;
	my $percent = ($dltotal == 0 ? "0" : int(100*$dlnow/+$dltotal));
	print $formatter->format_bytes($dlnow, unit => 'K') . " of " . $formatter->format_bytes($dltotal, unit => 'K') . " [" . $percent . "%]\r";
	return 0;
}

sub no_progress
{
	return 0;
}
