#!/usr/bin/perl -w

use strict;

package FileNames;

our $home = '/home/ross/';
our $ipodroot = '/media/ross/iPodClassic/';
our $root = $home . 'Downloads/New_Podcasts/';
our $podcastdir = 'Podcasts';
our $playlistdirname = 'Playlists';
our $musicdir = 'Music';
our $playlistfile = 'Podcasts.m3u8';
our $bookmark = '.rockbox/most-recent.bmark';

our $playlistdir = $root . $playlistdirname;
our $playlist = $playlistdir . '/' . $playlistfile;
our $basedir = $root . $podcastdir;
our $lockfile = $root . 'podcasts.lock';
our $archive = $root . 'archive/';

our $backup = $home . 'Documents/ipod/';
our $db_backup = $home . '/pCloudDrive/podcasts.sql';

our $ipodplaylist = $ipodroot . $playlistdirname;
our $ipodplaylistfile = $ipodroot . $playlistdirname . '/'. $playlistfile;
our $ipodbookmark = $ipodroot . $bookmark;
our $ipodmusic = $ipodroot . $musicdir . '/';
our $ipodpodcasts = $ipodroot . $podcastdir;

our $year = (localtime)[5] + 1900;
our $logfile = './logs/podcasts_' . $year . '.log';
our $templogfile = './logs/podcasts_temp.log';