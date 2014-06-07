#!/usr/bin/perl -w

use strict;

my $logfile = "/home/ross/scripts/podcasts/podcasts.log";
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

1;