#!/usr/bin/perl -w

use strict;

use Try;
use Net::MySQL;

require("/home/ross/scripts/podcasts/credentials.pl");

my $conn;

sub mysql_connect
{

	try
	{
		$conn = Net::MySQL->new(%DB::creds);
	}
	catch
	{
		die("Could not connect to database");
	}
	return $conn;
}

sub get_podcast_list
{
	my $conn = $_[0];
	my $podcast = $_[1];
	# Set up the MySQL query
	my $sql = "SELECT podcast_id, podcast_name, podcast_feed, podcast_last_downloaded FROM podcasts ";
	if ($podcast eq "")
	{
		$sql .= "WHERE podcast_skip = '0' ORDER BY podcast_name ASC";
	}
	else
	{
		if ($podcast =~ /\D/)
		{
			$sql .= "WHERE podcast_name = '$podcast'";
		}
		else
		{
			$sql .= "WHERE podcast_id = $podcast";
		}
	}
	$conn->query($sql);
	return $conn->create_record_iterator;
}

sub get_podcast_rows
{
	my $conn = $_[0];
	my $order = $_[1];
	$order = ($order eq "date" ? "podcast_last_downloaded DESC" : "podcast_name ASC");
	my $sql = "SELECT podcast_id, podcast_name, podcast_skip, podcast_last_downloaded FROM podcasts ORDER BY " . $order;
	$conn->query($sql);
	return $conn->create_record_iterator;
}

sub write_to_database
{
	my $conn = $_[0];
	my $id = $_[1];
	my $new_date = $_[2];
	$conn->query("UPDATE podcasts SET podcast_last_downloaded='$new_date' WHERE podcast_id=$id");
}

sub close_connection
{
	my $conn = $_[0];
	$conn->close;
}

sub dump_database
{
	#Back up db to the cloud
	system("mysqldump -upodcasts -ppodpass podcasts > '/home/ross/SpiderOak Hive/sql/podcasts.sql'");
}

1;
