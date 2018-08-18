#!/usr/bin/perl -w

use strict;

package DB;

our $tablename = "podcasts";

our %creds = ('hostname' => 'localhost',
			  'database' => 'podcasts',
			  'user'     => 'root',
			  'password' => 'root');

