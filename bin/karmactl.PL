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
# Karma Copyright (C) 1999  Sean Hull <shull@pobox.com>
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
# karmactl
#
# start, stop, reload, status of running karmad daemon
#
#------------------------------------------------------------------

#
# current version
#

require 5.004;
use strict;
use Getopt::Std;
use IO::File;
use karma;

$main::KARMA_HOME = ".";
if (defined $ENV{KARMA_HOME}) {
    $main::KARMA_HOME = $ENV{KARMA_HOME};
}

#
# look in the path if all else fails...
#
$main::KARMA = "karmad";
#
# look for karmad in the main::KARMA_HOME
#
if ((defined $ENV{KARMA_HOME}) && 
    (-e "$ENV{KARMA_HOME}$main::PATH_DELIM" . 'karmad') &&
    (-x "$ENV{KARMA_HOME}$main::PATH_DELIM" . 'karmad')) {
    $main::KARMA = "$ENV{KARMA_HOME}$main::PATH_DELIM" . 'karmad';

# 
# look for it in the current directory
#
} elsif ((-e '.' . "$main::PATH_DELIM" . 'karmad') && (-x '.' . "$main::PATH_DELIM" . 'karmad')) {
    $main::KARMA = '.' . "$main::PATH_DELIM" . 'karmad';
}



$main::KARMA_FIFO_NAME = "$main::KARMA_HOME$main::PATH_DELIM" . '.karmafifo';
$main::KARMA_PID_FILENAME = "$main::KARMA_HOME$main::PATH_DELIM" . '.karma.pid';
$main::KARMA_DOC="$main::KARMA_HOME$main::PATH_DELIM" . 'doc_root';

#
# needs windows support
#
$main::DEL_CMD = "/bin/rm";


#$main::opt_h = 0;
$main::opt_s = undef;
$main::opt_p = undef;
$main::opt_r = undef;
$main::opt_t = undef;
$main::opt_w = undef;
$main::opt_v = undef;
$main::opt_i = undef;
$main::opt_c = undef;
$main::opt_l = undef;
$main::opt_d = undef;
$main::opt_f = undef;
getopts('hspfrtwvi:k:l:c:d');

if (defined ($main::opt_w)) {
    printWarranty ();
}
if (defined ($main::opt_s)) {
    startKarma ();
}

#
# determine the process id if karma is already running
#
$main::KARMA_PID = 0;
if (defined ($main::opt_i)) {
    $main::KARMA_PID = $main::opt_i;
} else {
    $main::KARMA_PID = get_pid ();
}

if (defined ($main::opt_f)) {
    refreshKarma ();
}
if (defined ($main::opt_p)) {
    stopKarma ();
}
if (defined ($main::opt_r)) {
    reloadKarma ();
}
if (defined ($main::opt_t)) {
    statusKarma ();
}
if (defined ($main::opt_v)) {
    printVersion ();
}
if (defined ($main::opt_d)) {
    if (defined $main::opt_k) {
	$main::KARMA_DOC=$main::opt_k;
    }
    cleanupKarma ();
}

printHelp ();

#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
sub printHelp () {
    print 
	"\n",
	" -h print help and exit\n",
	" -v print version and exit\n",
	" -f force a refresh of all service statuses\n",
	" -w print warranty and exit\n",
	" -s start karmad daemon\n",
	" -p stop karmad daemon\n",
	" -t print status of running karmad daemon\n",
	" -r reload karam.conf config file\n",
	" -i specify process id (if lock file is missing)\n",
	" -l specify logfile for karmad (ignored if not starting karmad)\n",
	" -c specify karma config file (ignored if not starting karmad)\n",
	" -k specify karma doc_root\n",
	" -d delete dynamically created karma files (karma.html, info/*.html)",
	"\n",
	"$0 [-h|-v|-w|-s|-p|-t|-r|-d] [-l file] [-c file] [-k dir]\n";
    exit;
}

#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
sub startKarma () {

    print ("Starting karma daemon");
 
    my $COMMAND = "$main::KARMA";
    if ($main::opt_l) {
	print ", logfile: $main::opt_l";
	$COMMAND .= " -l $main::opt_l";
    }
    if ($main::opt_c) {
	print ", config: $main::opt_c";
	$COMMAND .= " -c $main::opt_c";
    }
    if ($main::opt_k) {
	print ", doc_root: $main::opt_k";
	$COMMAND .= " -k $main::opt_k";
    }
    print "...\n";

#    $COMMAND .= " &";

#    my $pid = 0;
#    if ($pid = fork) {
#	system ($COMMAND);
#    } 

    if ($main::WINDOWS == 0) {
	system ($COMMAND);
    } else {
	startWin32Process ($COMMAND);
    }
    #
    # give karma messages a chance to print
    #
    sleep (1);

    exit;
}


#-----------------------------------------------------------------------
#
# get main::KARMA_PID from lock file, send kill signal (TERM)
#
#-----------------------------------------------------------------------
sub stopKarma () {

    if ($main::KARMA_PID > 0) {
	print ("Stopping karma daemon - pid:$main::KARMA_PID...\n");
	kill TERM => $main::KARMA_PID
	    or die ("Can't stop pid:$main::KARMA_PID - $!\n");
    } else {
	print
	    "Can't determine process id from pid file, use -i to \n",
	    "specify on the command line.\n";
    }
    exit;
}


#-----------------------------------------------------------------------
#
# give karmad the USR2 signal to make all service statuses refresh
#
#-----------------------------------------------------------------------
sub refreshKarma () {

    if ($main::KARMA_PID > 0) {
	print ("Refreshing karma service statuses pid:$main::KARMA_PID...\n");
	kill USR2 => $main::KARMA_PID
	    or die ("Can't refresh pid:$main::KARMA_PID - $!\n");
    } else {
	print
	    "Can't determine process id from pid file, use -i to \n",
	    "specify on the command line.\n";
    }
    exit;
}

#-----------------------------------------------------------------------
#
# get main::KARMA_PID from lock file, send USR1 signal
#
#-----------------------------------------------------------------------
sub statusKarma () {

    my $line = "";
    if ($main::KARMA_PID > 0) {
#	print ("Getting status of karma daemon - pid:$main::KARMA_PID...\n");

	kill USR1 => $main::KARMA_PID
	    or die ("Can't get status of pid:$main::KARMA_PID - $!\n");

	open (FIFO, "<$main::KARMA_FIFO_NAME");
	while ($line = <FIFO>) {
	    
	    print ("$line");
	}
	close (FIFO);
    }    

    exit;
}


#-----------------------------------------------------------------------
#
# delete dynamically generated files in the karma doc_root directory
#
#-----------------------------------------------------------------------
sub cleanupKarma () {

    my $COMMAND = "";
    if (-d $main::KARMA_DOC) {
	if (-w $main::KARMA_DOC) {
	    $COMMAND = "$main::DEL_CMD $main::KARMA_DOC$main::PATH_DELIM" . 'karma.html';
	    system ($COMMAND);
	    $COMMAND = "$main::DEL_CMD $main::KARMA_DOC$main::PATH_DELIM" . 'info' . "$main::PATH_DELIM" . '*.html';
	    system ($COMMAND);
	} else {
	    print ("Cannot delete dynamic karma files: $main::KARMA_DOC\n");
	}
    } else {
	print ("Not a directory: $main::KARMA_DOC\n");
    }
    exit;
}



#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
sub reloadKarma () {

    if ($main::KARMA_PID > 0) {
	print ("Reloading karma.conf config pid:$main::KARMA_PID...\n");
	kill HUP => $main::KARMA_PID
	    or die ("Can't reread config file pid:$main::KARMA_PID - $!\n");
    } else {
	print
	    "Can't determine process id from pid file, use -i to \n",
	    "specify it on the command line the command line.\n";
    }
    exit;
}

#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
sub get_pid () {

    my $line = undef;

    $main::KARMA_PID_FILE = new IO::File "<$main::KARMA_PID_FILENAME";
    if (defined ($main::KARMA_PID_FILE)) {
	$line = <$main::KARMA_PID_FILE>;
	close ($main::KARMA_PID_FILE);
	if (defined ($line)) {
	    chomp ($line);
	    $line =~ s/\N//g;
	    return $line;
	}
    } else {
	print ("Can't seem to open pid file: $main::KARMA_PID_FILE - $!\n");
    }
    return 0;
}

#-----------------------------------------------------------------------
#
# startWin32Process
#
#-----------------------------------------------------------------------
sub startWin32Process ($) {
    my ($inCommand) = @_;

    system("start perl $inCommand");

#
# create a process in Windows
# (may use this if the above doesn't work...)
#
#Win32::Process::Create(
#  $oProcess, $sProg,
#  basename( $sProg ) . " " . $sParams,
#  0,
#  DETACHED_PROCESS,
#  "."
#);

}



#---------------------------------
#
# Plain Old Documentation (pod...)
#
#---------------------------------

=pod

=head1 NAME

Karma - karmactl

=head1 DESCRIPTION

The karmactl utility is used to control the main karma daemon
karmad.  Use it to start and stop the daemon, return status
of a running daemon, or reread the config file.

=head1 SYNOPSIS

Invoke the karmactl utility from the command line as follows:

C<$ ./karmactl -s>

use the C<-t> option to get the status of a running daemon, or
the C<-r> option to reread the config file:

C<$ ./karmactl -r>

When you want to stop the karmad daemon, you can do it like this:

C<$ ./karmactl -p>

Note that these commands are dependant on the process id of the
current running process.  If for some reason that pid wasn't 
written to the .karma.pid file, you may specify it manually
like this:

C<$ ./karmactl -p -i 2545>

=cut

!NO!SUBS!
