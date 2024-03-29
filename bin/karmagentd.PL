use Config;
use File::Basename qw(basename dirname);
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//i;
open OUT,">$file" or die "Can't create $file: $!";
chmod(0755, $file);
print "Extracting $file (with variable substitutions)\n";

print OUT <<"!GROK!THIS!";
$Config{'startperl'} -w

!GROK!THIS!

print OUT <<'!NO!SUBS!';
#------------------------------------------------------------------
# 
# Karma Copyright (C) 2000  Sean Hull <shull@pobox.com>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
#
#
#------------------------------------------------------------------
#
# karmagentd
#
# This script runs on the server machine (of each database you're
# monitoring, to get status of the OS (load average, % idle)
# and populate karma_os_stats with this information.  It also
# gathers information about any new ORA- errors in the alert.log
# and populates the karma_alertlog_errors table with it.
#
# Notes:  You don't HAVE to use this daemon at all.  If you don't,
# the OS and alert log columns will not be displayed in karma.
#
# You need to run one of these daemons for each instance which you
# want to gather these stats on (for now).  Sorry.
#
# Needs to run as the Oracle user...
#
#
#-----------------------------------------------------------------



#----------------------------------------------
# 
# PROTOTYPES
#
#----------------------------------------------
sub checkLine ($);
sub readPosition ($);
sub writePosition ($$);
sub debugPrint ($$);
sub printHelp ();
sub dbConnect ();

use Getopt::Std;
use karma;
use strict;
use Term::ReadKey;


BEGIN {
    unless (eval "require DBI") {
	print 
	    "You must have DBI installed to use karma.\n",
	    "Please install it first, and try again.\n";
	exit 1;
    }
}

BEGIN {
    unless (eval "require DBD::Oracle") {
	print
	    "You must have DBD::Oracle installed to use karma.\n",
	    "Please install it first, and try again.\n";
	exit 1;
    }
}


use IO::File;
require 5.004;

#
# needs windows support
#
$main::CMD_UPTIME = undef;
if ($main::WINDOWS == 0) {
    $main::CMD_UPTIME = '/usr/bin/uptime';
}

#
# get the command line options
#
$main::opt_h = undef;
$main::opt_t = undef;
$main::opt_u = undef;
$main::opt_f = undef;
$main::opt_r = undef;
$main::opt_j = undef;
$main::opt_p = undef;
$main::opt_k = undef;
$main::opt_s = undef;
$main::opt_b = undef;
$main::opt_h = undef;
$main::opt_d = undef;
$main::opt_w = undef;
$main::opt_v = undef;
$main::opt_l = undef;
getopts('ht:u:f:a:rp:j:s:b:h:d:k:vwl:');

if (defined $main::opt_v) {
    printVersion ();
}
if (defined $main::opt_w) {
    printWarranty ();
}
if (defined $main::opt_h) {
    printHelp ();
}

$main::DEBUG_LEVEL = undef;
if (defined $main::opt_d) {
    $main::DEBUG_LEVEL = $main::opt_d;
}

if (defined $main::opt_s) {
    $ENV{ORACLE_SID} = $main::opt_s;
}
if (defined $main::opt_b) {
    $ENV{ORACLE_BASE} = $main::opt_b;
}
if (defined $main::opt_h) {
    $ENV{ORACLE_HOME} = $main::opt_h;
}
if (defined $main::opt_r) {
    resetAlertlog ();
}

$main::TNS = '';
if (defined $main::opt_t) {
    $main::TNS = $main::opt_t;
} 
$main::DSN = "DBI:Oracle:$main::TNS";
if (defined ($ENV{DBI_DSN})) {
    $main::DSN = $ENV{DBI_DSN};
}
#
# default to the OFA location
#
#print ("BEFORE USE OF UNINIT VALUE...\n");
#print ("PATH_DELIM: $main::PATH_DELIM\n");
#print ("ORACLE_HOME: $ENV{ORACLE_HOME}\n");
#print ("ORACLE_BASE: $ENV{ORACLE_BASE}\n");
#print ("ORACLE_SID: $ENV{ORACLE_SID}\n");

$main::ALERTLOG_FILE = undef;
$main::ALERTLOG_FILE = "$ENV{ORACLE_BASE}$main::PATH_DELIM" . 'admin' . "$main::PATH_DELIM$ENV{ORACLE_SID}" . "$main::PATH_DELIM" . 'bdump' . "$main::PATH_DELIM" . "alert_$ENV{ORACLE_SID}.log";

if ($main::WINDOWS == 0) {
    $main::wd = `/bin/pwd`;
} else {
    $main::wd = Win32::GetCwd ();
}
chomp $main::wd;

if (defined $main::opt_a) {
    if ($main::WINDOWS == 1) {
	if ($main::opt_l =~ /^\w:/) {
	    $main::ALERTLOG_FILE = $main::opt_a;
	} else {
	    $main::ALERTLOG_FILE = $main::wd .
		$main::PATH_DELIM . $main::opt_a;
	}
    } else {
	if (($main::opt_a =~ /^\./) ||
	    ($main::opt_a =~ /^\//)) {
	    $main::ALERTLOG_FILE = $main::opt_a;
	} else {
	    $main::ALERTLOG_FILE = $main::wd
		. $main::PATH_DELIM . $main::opt_a;
	}
    }
}
$main::PASS = 'manager';
if (defined $main::opt_p) {
    $main::PASS = $main::opt_p;
} elsif (defined ($ENV{DBI_PASS})) {
    $main::PASS = $ENV{DBI_PASS};
} else {
    print ('Password: ');

    # read password new way, without echo
    ReadMode ('noecho');
    $main::PASS = ReadLine(0);

    # this is pretty important.  Without login always fails because
    # the password is wrong.
    chomp($main::PASS);
    ReadMode ('normal');
    print ("\n");

#    $main::PASS = <STDIN>;
#    chomp ($main::PASS);
}

$main::USER = 'karma';
if (defined $main::opt_u) {
    $main::USER = $main::opt_u;
} elsif (defined ($ENV{DBI_USER})) {
    $main::USER = $ENV{DBI_USER};
}
my $FREQUENCY = 300;
if (defined $main::opt_f) {
    $FREQUENCY = $main::opt_f * 60;
}

#my $POSITION_FILE = ".karmagent.sav";
#if (defined $main::opt_k) {
#    $POSITION_FILE = $main::opt_k;
#}

if ($main::WINDOWS == 0) {
    $main::wd = `/bin/pwd`;
} else {
    $main::wd = Win32::GetCwd ();
}
chomp $main::wd;

$main::POSITION_FILE = $main::wd . $main::PATH_DELIM . '.karmagent.sav';
if (defined $main::opt_k) {

    if ($main::WINDOWS == 1) {
        if ($main::opt_k =~ /^\w:/) {
            $main::POSITION_FILE = $main::opt_k;
        } else {
            $main::POSITION_FILE = $main::wd .
                $main::PATH_DELIM . $main::opt_k;
        }
    } else {
        if (($main::opt_k =~ /^\./) ||
            ($main::opt_k =~ /^\//)) {
            $main::POSITION_FILE = $main::wd
                . $main::PATH_DELIM . $main::opt_k;
        } else {
            $main::POSITION_FILE = $main::opt_k;
        }
    }
}


#
# set the logfile name
#
$main::LOG_FILE_NAME = 'karmagent.log';
if (defined ($main::opt_l)) {
    if ($main::WINDOWS == 1) {
	if ($main::opt_l =~ /^\w:/) {
	    $main::LOG_FILE_NAME = $main::opt_l;
	} else {
	    $main::LOG_FILE_NAME = $main::wd .
		$main::PATH_DELIM . $main::opt_l;
	}
    } else {
	if (($main::opt_l =~ /^\./) ||
	    ($main::opt_l =~ /^\//)) {
	    $main::LOG_FILE_NAME = $main::wd
		. $main::PATH_DELIM . $main::opt_l;
	} else {
	    $main::LOG_FILE_NAME = $main::opt_l;
	}
    }
}

print ("Starting karmagentd monitoring daemon...\n");

#
# background ourselves
#
if (($main::WINDOWS == 0) && 
    (not (defined $main::DEBUG_LEVEL))) {
    daemonize ();
}

$main::logfile = new IO::File ">>$main::LOG_FILE_NAME";
if (not (defined $main::logfile)) {
    $main::logfile = new IO::File ">>-";
    logMessage ("Cannot open logfile: $main::LOG_FILE_NAME, using STDOUT");
}

#
# unbuffer output
#
if (defined $main::logfile) {
    select ($main::logfile); $| = 1;
    select (STDOUT);
}

#
# background ourselves
#
#if (($main::WINDOWS == 0) && 
#    (not (defined $main::DEBUG_LEVEL))) {
#    daemonize ();
#}

#
# signal handlers...
#
if ($main::WINDOWS == 0) {
    $SIG{TERM} = \&catchTerm;
    $SIG{HUP} = \&catchHup;
}

$main::cALERT_POSITION = 'alert_position';
$main::cBEGINNING_OF_FILE = 0;

@main::uptimes = ();
#$main::UPCMD = "uptime";
$main::uptimeString = "";



if ($main::WINDOWS == 0) {
    debugMessage ("   IS Win32:NO\n", 1);
} else {
    debugMessage ("   IS Win32:YES\n", 1);
}
debugMessage ("WORKING DIR:$main::wd\n", 1);
debugMessage ("   LOG FILE:$main::LOG_FILE_NAME\n", 1);
debugMessage ("DEBUG_LEVEL:$main::DEBUG_LEVEL\n", 1);
debugMessage ("ORACLE_BASE:$ENV{ORACLE_BASE}\n", 1);
debugMessage ("ORACLE_HOME:$ENV{ORACLE_HOME}\n", 1);
debugMessage (" ORACLE_SID:$ENV{ORACLE_SID}\n", 1);
debugMessage (" ORACLE_SID:$ENV{ORACLE_SID}\n", 1);
debugMessage ("   POS_FILE:$main::POSITION_FILE\n", 1);

# 
# statements for inserting data into the db
#
$main::uptimeStatement =
    'INSERT INTO karma_os_stats VALUES (sysdate, ?, ?, ?, 0)';
$main::alertlogStatement =
    'INSERT INTO karma_alertlog_errors VALUES (sysdate, ?, ?, ?)';
$main::agentStatement = 
    'UPDATE karma_agent SET timestamp = SYSDATE, frequency = ? WHERE id = \'LASTUPDATE\'';

#
# database handle
#
debugMessage ("Connecting - DSN:$main::DSN USER:$main::USER PASS:$main::PASS\n", 2);

$main::dbh = undef;
$main::uptimeSth = undef;
$main::alertlogSth = undef;

#$main::dbh = DBI->connect ($main::DSN, $main::USER, $main::PASS);
#print ("before first dbConnect\n");
dbConnect ();


if (defined $main::dbh) {
    # logfile isn't open yet...
    # only visible with debug options on...
    #logMessage ("Successfully connected to $main::USER DSN:$main::DSN...\n");
    print ("Successfully connected to $main::USER DSN:$main::DSN...\n");
} else {
    # logfile isn't open yet
    print ("Failed to connect to $main::USER DSN:$main::DSN - Exiting.\n");
    #logMessage ("Failed to connect to $main::USER DSN:$main::DSN - Exiting.\n");
    exit 1;
}


$main::prevTime = getDayMinutes (time ());
$main::currTime = 0;

$main::currLine = '';
$main::currPosition = 0;
if (defined $main::opt_j) {
    $main::currPosition = $main::opt_j;
} else {
    $main::currPosition = readPosition ($main::POSITION_FILE);
}

debugMessage ("Reading alertlog: $main::ALERTLOG_FILE\n", 1);
debugMessage ("Start reading at byte $main::currPosition\n", 1);
$main::alert_file = new IO::File "<$main::ALERTLOG_FILE";
if (not ($main::alert_file)) {
    logMessage ("Could not open alertlog file.  Exiting.\n");
    exit 1;
}

seek ($main::alert_file, $main::currPosition, $main::cBEGINNING_OF_FILE);

while (1) {
    if ((not (defined $main::dbh)) ||
	(not (defined $main::uptimeSth)) ||
	(not (defined $main::alertlogSth))) {
	dbConnect ();
    } else {
        #if (($main::currTime == 0) || ($main::currTime >= $main::prevTime + $FREQUENCY)) {

	$main::prevTime = $main::currTime;
	
	# 
	# fetch the most current uptime stats
	#
	$main::uptimeString = `$main::CMD_UPTIME`;
	chop ($main::uptimeString);
	$main::uptimeString =~ s/^.*://;
	@main::uptimes = split (',', $main::uptimeString);
	debugMessage ("INSERTING OS VALUES: $main::uptimes[0], $main::uptimes[1], $main::uptimes[2]\n", 2);
	$main::uptimeSth->execute ($main::uptimes[0], $main::uptimes[1], $main::uptimes[2]);

	updateKarmaAgent ();
	checkAlertFile ();

	debugMessage ("Sleeping for $FREQUENCY seconds...\n", 1);
	sleep ($FREQUENCY);

	$main::currTime = getDayMinutes (time ());
    }
}


#--------------------------------------------------------------
#
#    ROUTINES
#
#--------------------------------------------------------------


#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
sub updateKarmaAgent () {

    if (defined $main::dbh) {
    
	my $freq = $FREQUENCY/60;
	my $sth = $main::dbh->prepare ($main::agentStatement);
	
	if (defined $sth) {
	    my $rv = $sth->execute ($freq);
	    $sth->finish;
	}
    }
}

#-----------------------------------------------------------------------
#
# returns the time of day in minutes
#
#-----------------------------------------------------------------------
sub printHelp () {

    print 
	("\n",
	 " v - print version info and exit\n",
	 " h - print this help info\n",
	 " f - fequency in minutes to wakeup & check things (default 5)\n",
	 " r - reset the alert.log, and truncate it's table\n",
	 " u - user to login as (default karma)\n",
	 " p - oracle login password (otherwise you're prompted)\n",
	 " j - jump j bytes in file (takes precedence over save file)\n",
	 " t - tnsname of the database to watch (default local)\n",
	 " a - specify alert.log file (default OFA)\n",
	 " k - use this file to store seek position\n",
	 " b - specify ORACLE_BASE (takes precedence over env)\n",
	 " h - specify ORACLE_HOME (takes precedence over env)\n",
	 " s - specify ORACLE_SID (takes precedence over env)\n",
	 " d - debug level (default 0, no debugging)\n",
	 " w - print the warranty and exit\n",
	 " l - specify logfile to write messages to \n",
	 "\n",
	 "$0 [-h] [-f \#] [-r] [-u karma] [-p pass] [-j \#] [-t DB]\n",
	 "\t[-a alert.log] [-k karmagent.sav] [-b ORACLE_BASE]\n",
	 "\t[-h ORACLE_HOME] [-s ORACLE_SID] [-d \#]\n");
    
    exit 1;

}


#--------------------------------------------------------------
#
# checkLine
#
#--------------------------------------------------------------
sub checkLine ($) {
    my ($inLine) = @_;

    my $fac = undef;
    my $err = undef;
    my $msg = undef;
    #my $noErrors = undef;

    if ($inLine =~ /^ORA-/) {

	debugMessage ("ERRORS --- $inLine\n", 1);

	$fac = $inLine;
	$fac =~ s/-.*//;
	
	$err = $inLine;
	$err =~ s/$fac-//;
	$err =~ s/\D.*//;
	
	$msg = $inLine;
	$msg =~ s/$fac-$err//;

	#$facility = 'ORA';
	#$errNum = $inLine;
	#$errNum =~ s/^ORA-//;
	#$errNum =~ s/\s.*$//;
	#$errText = $inLine;
	#$errText =~ s/^ORA-//;
	#$errText =~ s/^\d*\s//;
	#$noErrors = 0;

#	return [$facility, $errNum, $errText];
	return [$fac, $err, $msg];
    }
    
    return undef;
}

#--------------------------------------------------------------
#
#
#
#--------------------------------------------------------------
sub readPosition ($) {
    my ($inFile) = @_;

    my $currLine = '';
    my $retPos = 0;

    
    my $pos_file = new IO::File "<$inFile";
    if (defined $pos_file) {
	while (<$pos_file>) {
	    $currLine = $_;
	    chomp $currLine;
	    if ($currLine =~ /$main::cALERT_POSITION/) {
		$currLine =~ s/^.*$main::cALERT_POSITION://;
		$currLine =~ s/\D*//;
		$retPos = $currLine;
	    }
	}
	
	$pos_file->close;
    } else {
	logMessage ("Can't open position file: $!\n");
    }
    
    return $retPos;
}

#--------------------------------------------------------------
#
#
#
#--------------------------------------------------------------
sub writePosition ($$) {
    my ($inFile, $inPos) = @_;

    my $pos_file = new IO::File ">$inFile";
    if (defined $pos_file) {
	print $pos_file ("$main::cALERT_POSITION:$inPos\n");
	$pos_file->close; 
    } else {
	logMessage ("Cannot write to position file.  $!\nPosition will not be saved.\n");
    }

}

#--------------------------------------------------------------
#
#
#
#--------------------------------------------------------------
sub resetAlertlog () {
    debugMessage ("ResetAlertlog not implemented yet.\n", 1);
    $main::currPosition = 0;
    seek ($main::alert_file, $main::currPosition, $main::cBEGINNING_OF_FILE);
    checkAlertFile ();
}

#--------------------------------------------------------------
#
# reread config file (HUP signal)
#
#--------------------------------------------------------------
sub catchHup {
    resetAlertlog ();
}

#--------------------------------------------------------------
#
# normal kill
#
#--------------------------------------------------------------
sub catchTerm {
    debugMessage ("Exit cleanly.\n", 1);
    writePosition ($main::POSITION_FILE, $main::currPosition);
    
    $main::logfile->close;

    #
    # cleanup and exit
    #
    if (defined $main::uptimeSth) {
	$main::uptimeSth->finish;
    }
    if (defined $main::alertlogSth) {
	$main::alertlogSth->finish;
    }
    if (defined $main::dbh) {
	$main::dbh->disconnect;
    }
    exit 0;

}

#----------------------------------------------------------------
#
#
#
#----------------------------------------------------------------
sub dbConnect () {
    $main::dbh = undef;
    $main::dbh = DBI->connect ($main::DSN, $main::USER, $main::PASS);

#    print ("inside dbConnect\n");
    if (defined $DBI::errstr) {
	print ("ERROR: $DBI::errstr\n");
    }

    if (defined $main::dbh) {

	my $haveOS = checkForTable ('KARMA_OS_STATS');
	my $haveAGENT = checkForTable ('KARMA_AGENT');
	my $haveALERT = checkForTable ('KARMA_ALERTLOG_ERRORS');

	if (($haveOS == 1) && ($haveAGENT == 1) && ($haveALERT == 1)) {
	    #
	    # prepare the statements
	    #
	    $main::uptimeSth = undef;
	    $main::uptimeSth = $main::dbh->prepare ($main::uptimeStatement);
	    if (defined $DBI::errstr) {
		logMessageWTime ("doConnect uptime prepare - $DBI::errstr\n");
	    }
	    
	    $main::alertlogSth = undef;
	    $main::alertlogSth = $main::dbh->prepare ($main::alertlogStatement);
	    if (defined $DBI::errstr) {
		logMessageWTime ("dbConnect alertlog prepare - $DBI::errstr\n");
	    }
	} else {
	    if ($haveOS == 0) {
		logMessageWTime ("dbConnect: table KARMA_OS_STATS not found - Exiting\n");
	    } elsif ($haveAGENT == 0) {
		logMessageWTime ("dbConnect: table KARMA_AGENT not found - Exiting\n");
	    } elsif ($haveALERT == 0) {
		logMessageWTime ("dbConnect: table KARMA_ALERT not found - Exiting\n");
	    }

	    $main::dbh->disconnect;
	    exit 1;
	}
    }
}

#----------------------------------------------------------------
#
#
#
#----------------------------------------------------------------
sub checkForTable ($) {
    my ($inTable) = @_;

    my $retval = 0;

    if (defined $main::dbh) {
	my $sth = $main::dbh->prepare ('SELECT table_name FROM user_tables WHERE table_name = ?');
	my $rv = $sth->execute($inTable);
	my $rowref = $sth->fetchrow_arrayref;
	if ((defined $rowref) && ($rowref->[0] =~ /^$inTable$/)) {
	    $retval = 1;
	} 
	$sth->finish;
    }

    return $retval;
}

#----------------------------------------------------------------
#
#
#
#----------------------------------------------------------------
sub checkAlertFile () {

    #
    # fetch any new alert log errors
    #
    if ((defined $main::alert_file) && 
	(defined $main::alertlogSth)) {
	while (<$main::alert_file>) {
	    $main::currLine = $_;
	    chomp ($main::currLine);
	    $main::lineNum++;	
	    if ($main::lineNum % 50 == 0) {
	    	debugMessage ("LINE:$main::lineNum\n", 3);
	    }
	    $main::currPosition = tell;
	    
	    debugMessage ("TESTING - $main::currLine\n", 3);
	    $main::lineRef = undef;
	    $main::lineRef = checkLine ($main::currLine);
	    
	    if (defined $main::lineRef) {
		debugMessage ("INSERTING ALERTLOG VALS: $main::lineRef->[0], $main::lineRef->[1], $main::lineRef->[2]\n", 2);
		$main::alertlogSth->execute ($main::lineRef->[0],
					     $main::lineRef->[1],
					     $main::lineRef->[2]);
	    }
	}
    
	writePosition ($main::POSITION_FILE, $main::currPosition);
    }
}

#---------------------------------
#
# Plain Old Documentation (pod...)
#
#---------------------------------

=pod

=head1 NAME

Karma - karmagentd

=head1 DESCRIPTION

The karmagentd daemon is an additional utility which is used
in conjunction with OS and/or alertlog monitoring.  In order
for karmad to find valid information regarding either of these
services, this daemon must be running on each target database.

=head1 SYNOPSIS

The karmagentd daemon checks statistics from the operating
system and inserts them into a table called karma_os_stats
in the target database.  If this table is missing, 
karmagentd will continue running supporting alertlog
monitoring, if possible.

The karmagentd daemon's more important functionality is in
monitoring your alertlog on designated destination databases.
It does this by reading through the file on startup, and
then waking up periodically to check for changes.  If it finds
any 'ORA-' errors, it will insert the timestamp, and error
along with the associated text into the 
karma_alertlog_errors table.  If this table doesn't exist,
and karmagentd failed to do gather OS statistics, it will
exit with a message.  Additionally, karmagentd attempts to
use the .karmagent.sav file to store the current seek point
into the alertlog file, so it can start from where it left off.

=head1 NOTES

The basic way to invoke karmagentd is as follows:

C<$ ./karmagentd -u karma -t mydb>

Invoked this way, without specifying the password on the
command line is best.  If you choose to specify the password
on the command line, it can be viewed via the operating
system command 'ps', or equivalent on Win32 platforms, which
presents a rather large security hole, and is not recommended.
Instead, invoke as described above, and karmagentd will
simply prompt you for the password.

Optionally, the alertlog file can be specified explicitely
C<-a /opt/oracle/admin/mydb/bdump/alertmydb.log>, however if
it is in the standard OFA location, karmagentd should find
it.

=cut

!NO!SUBS!

