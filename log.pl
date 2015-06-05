#!/usr/bin/perl -w

use strict;
use File::Copy qw(mv);

my $year = (localtime)[5] + 1900;

my $logfile = "/home/ross/scripts/podcasts/logs/podcasts_" . $year . ".log";
my $tempfile = "/home/ross/scripts/podcasts/logs/podcasts_temp.log";
my $loghandle;

sub writelog
{
	my $string = $_[0];
	my $break = (defined($_[1]) ? $_[1] : 0);
	chomp($string);
	open ($loghandle, ">>", $logfile);
	print $loghandle gettime() . " -- " . $string . "\n";
	print $loghandle "-" x 19 . "\n" if ($break == 1);
	close($loghandle);
#	redirect();
}

sub gettime
{
	 my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
	 $sec  = (length($sec)  == 1 ? "0" . $sec  : $sec);
	 $min  = (length($min)  == 1 ? "0" . $min  : $min);
	 $hour = (length($hour) == 1 ? "0" . $hour : $hour);
	 $mon += 1;
	 $mon  = (length($mon)  == 1 ? "0" . $mon  : $mon);
	 $mday = (length($mday) == 1 ? "0" . $mday : $mday);
	 return ((1900 + $year) . "-" . $mon . "-" . $mday . " " . $hour . ":" . $min . ":" . $sec);
}

sub redirect
{
	mv ($logfile, $tempfile);
	sleep (1);
	mv ($tempfile, $logfile);
}

1;