#!/usr/bin/perl -w

use strict;

use Try;
use Net::MySQL;
use Switch;

require("/home/ross/scripts/podcasts/credentials.pl");
# Logging functions
require("/home/ross/scripts/podcasts/log.pl");

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

sub toggle_podcast
{
	my $conn = $_[0];
	my $podcast = $_[1];
	my $toggle = $_[2];
	my $where;
	my $sql = "UPDATE " . $DB::tablename . " set podcast_skip = ";
	if ($toggle eq "on")
	{
		$sql .= "'0' ";
	}
	else
	{
		$sql .= "'1' ";
	}
	if ($podcast =~ /\D/)
	{
		$where = "WHERE podcast_name = '$podcast'";
	}
	else
	{
		$where = "WHERE podcast_id = $podcast";
	}
	$sql .= $where;
	$conn->query($sql);
	#Get details to return
	$sql = "SELECT podcast_id, podcast_name, podcast_skip FROM " . $DB::tablename . " " . $where;
	$conn->query($sql);
	return $conn->create_record_iterator;
}

sub add_podcast {
	my $conn   = $_[0];
	my $name   = $_[1];
	my $url    = $_[2];
	my $toggle = $_[3];
	$toggle = ($toggle eq "on" ? "0" : "1");

	my $sql = "CREATE TABLE IF NOT EXISTS `" . $DB::tablename . "` (`podcast_id` SMALLINT(5) NOT NULL AUTO_INCREMENT, `podcast_name` VARCHAR(50) NOT NULL, `podcast_feed` VARCHAR(100) NOT NULL, `podcast_skip` ENUM('0','1') NOT NULL DEFAULT '0', `podcast_last_downloaded` DATETIME NOT NULL, PRIMARY KEY (`podcast_id`) ) ENGINE=InnoDB AUTO_INCREMENT=32 DEFAULT CHARSET=latin1;";
	$conn->query($sql);

	$sql = "INSERT INTO " . $DB::tablename . " (podcast_name, podcast_feed, podcast_skip, podcast_last_downloaded) ";
	$sql   .= "VALUES ('$name', '$url', '$toggle', '2000-01-01 00:00:00')";
	$conn->query($sql);
	return $conn->create_record_iterator;
}

sub get_podcast_list
{
	my $conn = $_[0];
	my $podcast = $_[1];
	# Set up the MySQL query
	my $sql = "SELECT podcast_id, podcast_name, podcast_feed, podcast_last_downloaded FROM " . $DB::tablename . " ";
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
	switch ($order) {
		case "date" {
			$order = "podcast_last_downloaded DESC";
		}
		case "name" {
			$order = "podcast_name ASC";
		}
		case "id" {
			$order = "podcast_id ASC";
		}
	}
	my $sql = "SELECT MAX(CHAR_LENGTH(podcast_id)) AS podcast_id, MAX(CHAR_LENGTH(podcast_name)) AS podcast_name, 1 AS podcast_skip, 18 AS podcast_last_downloaded, 1 AS sort FROM " . $DB::tablename;
	$sql .= " UNION SELECT podcast_id, podcast_name, podcast_skip, podcast_last_downloaded, 2 FROM " . $DB::tablename . " order by sort ASC, " . $order;
	$conn->query($sql);
	return $conn->create_record_iterator;
}

sub write_to_database
{
	my $conn = $_[0];
	my $id = $_[1];
	my $new_date = $_[2];
	$conn->query("UPDATE " . $DB::tablename . " SET podcast_last_downloaded='$new_date' WHERE podcast_id=$id");
}

sub close_connection
{
	my $conn = $_[0];
	$conn->close;
}

sub dump_database
{
	#Back up db to the cloud
	system("mysqldump -uroot -proot " . $DB::tablename . " > '/home/ross/SpiderOak Hive/sql/podcasts.sql'");
}

1;
