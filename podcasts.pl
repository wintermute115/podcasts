#!/usr/bin/perl -w

#Automatically downloads podcasts to my computer so they
#can be copied to my iPod.

#Runs as a cron job every hour.

use strict;
use Getopt::Long;
use IO::Uncompress::Gunzip qw(gunzip);
use Net::Curl::Easy qw(:constants);
use Net::MySQL;
use Number::Format;
use Term::ANSIColor;
use Time::Local;
use Try;
use XML::RSS;

# MySQL functions
require("/home/ross/scripts/podcasts/connect.pl");
# Logging functions
require("/home/ross/scripts/podcasts/log.pl");

my %playlist;
my $updated_config = "";
my $final_data;
my $total_size;

my $root = "/home/ross/Downloads/New Podcasts/";

my $basedir = $root . "Podcasts";
my $playlistdir = $root . "Playlists";
my $lockfile = $root . "podcasts.lock";
my $archive = $root . "archive/";

binmode STDOUT, ":utf8";

# Commandline options
my $podcast = "";
my $caller = "user";
my $result = GetOptions("caller=s"  => \$caller,
	                    "podcast=s" => \$podcast);

# MySQL object
my $conn = mysql_connect();


if ($caller eq "boot" && -e($lockfile))
{
	#Didn't clean up the lockfile on shutdown	
	unlink($lockfile);
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

# Set up the MySQL query
my $sql = "SELECT podcast_id, podcast_name, podcast_feed, podcast_last_downloaded FROM podcasts ";
if ($podcast eq "")
{
	$sql .= "WHERE podcast_skip = '0' ORDER BY podcast_name ASC";
}
else
{
	$sql .= "WHERE podcast_name = '$podcast'";
}
$conn->query($sql);
my $rs = $conn->create_record_iterator;

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
		my $last_download = timelocal($sec, $min, $hour, $day, $mon - 1, $year - 1900);
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
		if ($broken)
		{
			print "\n";
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
		foreach my $item (@{$parser->{'items'}})
		{
			#Check each item in the feed
			my $title = $item->{'title'};
			$title =~ s/\x{2013}/-/g; #Convert long hyphens to ASCII equivalent
			my $pubdate = parse_date($item->{'pubDate'});
			my $type = $item->{'enclosure'}->{'type'};
			my $url = $item->{'enclosure'}->{'url'};
			$url = (defined($url) ? $url : "");
			$url =~ /([^\/]*)$/; #separate out the filename
			my $fname = $1;
			$new_last_download = ($pubdate > $new_last_download ? $pubdate : $new_last_download);
			next if ($pubdate <= $last_download); #If we've cycled through all the newer ones, stop now.
			if (defined($type) && $type =~ /^audio\//i)
			{
				#Only download audiofiles
				print color 'bold';
				my $note = "Downloading \"$title\" [$fname]";
				writelog($note);
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
				mkdir($basedir) unless (-d($basedir));
				mkdir("$basedir/$name") unless (-d("$basedir/$name"));
				open(my $write_handle, ">", "$basedir/$name/$fname");
				binmode($write_handle);
				print $write_handle $final_data;
				close($write_handle);
				# Track the file for the playlist
				$playlist{$pubdate . $title} = "/Podcasts/$name/$fname";
				print color 'reset';
			}
		}
		# Update the last downloaded time in the database
		my ($new_sec, $new_min, $new_hr, $new_day, $new_mon, $new_year, $new_wday, $new_yday, $new_isdst) = localtime($new_last_download);
		my $new_date = ($new_year + 1900) . "-" . sprintf("%0*d", 2, $new_mon + 1) . "-" . sprintf("%0*d", 2, $new_day) . " " . sprintf("%0*d", 2, $new_hr) . ":" . sprintf("%0*d", 2, $new_min) . ":" . sprintf("%0*d", 2, $new_sec);
		$conn->query("UPDATE podcasts SET podcast_last_downloaded='$new_date' WHERE podcast_id=$id");
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
}
unlink($lockfile) or die ("Cannot delete lockfile: $!");

$conn->close;

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
	$datestr =~ /(\d{1,2}) ([[:alpha:]]{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})/;
	my $day = $1;
	my $mon = $months{lc($2)};
	my $year = $3 - 1900;
	my $hour = $4;
	my $min = $5;
	my $sec = $6;
	return (timelocal($sec, $min, $hour, $day, $mon, $year));
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