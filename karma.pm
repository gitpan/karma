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
# karma.pm
#
# common code for karmad, karmagentd, karmactl
#
#------------------------------------------------------------------

use POSIX 'setsid';

$main::WINDOWS = 0;
$main::PATH_DELIM = '/';
if (eval 'require Win32') {
    if ((Win32::IsWin95 ()) || (Win32::IsWinNT ())) {
	$main::WINDOWS = 1;
	$main::PATH_DELIM = '\\';
    }
}

sub padNum ($$);
sub getCurrTimeString ($);
sub getFullTimeString ($);
sub getTimeString ($);
sub printWarranty ();
sub printVersion ();
sub logMessage ($);
sub logMessageWTime ($);
sub debugMessage ($$);
sub getDayMinutes ($);

#
# current version
#
# perl standards like real number version numbers, so for
# now we'll drop the linux convention...
#
$main::KVERSION='1.0.0';
$main::VERSION='1.00';
$main::DEBUG_LEVEL = 0;

#
# documentation colors
#
$main::DOC_BG = '#003399';
$main::DOC_LINK = '#996633';
$main::DOC_VLINK = '#996633';
$main::DOC_ALINK = '#ff9933';


#-----------------------------------------------------------------------
#
# print version and exit
#
#-----------------------------------------------------------------------
sub printVersion () {
    print 
	"\n",
	"  Karma v$main::VERSION Copyright (C) 2000 Sean Hull <shull\@pobox.com>\n",
	"  Karma comes with ABSOLUTELY NO WARRANTY; for details\n",
	"  type \"karmad -w\".  This is free software, and you are\n",
	"  welcome to redistribute it under certain conditions.\n\n";
    
    exit ;
}


#-----------------------------------------------------------------------
#
# GNU General Public License Warranty
#
#-----------------------------------------------------------------------
sub printWarranty () {
    print 
	"\n",
	"   Copyright (C) 2000  Sean Hull <shull\@pobox.com>\n",
	"\n",
	"   This program is free software; you can redistribute it and/or modify\n",
	"   it under the terms of the GNU General Public License as published by\n",
	"   the Free Software Foundation; either version 2 of the License, or\n",
	"   (at your option) any later version.\n",
	"\n",
	"   This program is distributed in the hope that it will be useful,\n",
	"   but WITHOUT ANY WARRANTY; without even the implied warranty of\n",
	"   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n",
	"   GNU General Public License for more details.\n",
	"\n",
	"   You should have received a copy of the GNU General Public License\n",
	"   along with this program; if not, write to the Free Software\n",
	"   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA\n",
	"\n";


   exit;
}

#-----------------------------------------------------------------------
#
# write message to logfile
#
#-----------------------------------------------------------------------
sub logMessage ($) {
    my ($message) = @_;

    if (defined ($main::logfile)) {
	print $main::logfile ($message);
    } else {
	print ($message);
    }
}


#-----------------------------------------------------------------------
#
# log a message with a timestamp
#
# should this use $currTime??
#
#-----------------------------------------------------------------------
sub logMessageWTime ($) {
    my ($inMessage) = @_;

    my $theTimeStr = getCurrTimeString ($main::currTime);
    logMessage ("$theTimeStr - $inMessage");
}


#-----------------------------------------------------------------------
#
# convert the given time to a string
#  of the form 14:25
#
#-----------------------------------------------------------------------
sub getTimeString ($) {
    my ($inTime) = @_;
    my $sec = undef;
    my $min = undef;
    my $hour = undef;
    my $mday = undef;
    my $mon = undef;
    my $year = undef;
    my $wday = undef;
    my $yday = undef;
    my $isdst = undef;

    #
    # get the time and break it into it's components
    #
    ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime ($inTime);

    #
    # adjust minutes, or just put hour and minutes together for time
    # string
    #
    my $hourStr = padNum ($hour, 2);
    my $minStr = padNum ($min, 2);
    $timeStr = "$hourStr:$minStr";

    return $timeStr;
}



#-----------------------------------------------------------------------
#
# convert the given time to a string
#  of the form "MM/DD/YYYY HH:MI"
#
#-----------------------------------------------------------------------
sub getFullTimeString ($) {
    my ($inTime) = @_;
    my $sec = undef;
    my $min = undef;
    my $hour = undef;
    my $mday = undef;
    my $mon = undef;
    my $year = undef;
    my $wday = undef;
    my $yday = undef;
    my $isdst = undef;

    #
    # get the time and break it into it's components
    #
    ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
	localtime ($inTime);

    # localtime returns current year - 1900 so...
    $year += 1900;

    #
    # adjust minutes, or just put hour and minutes together for time
    # string
    #
    my $hourStr = padNum ($hour, 2);
    my $minStr = padNum ($min, 2);
    my $dayStr = padNum ($mday, 2);
    my $monStr = padNum (($mon + 1), 2);
    $timeStr = "$monStr/$dayStr/$year $hourStr:$minStr";

    return $timeStr;
}

#---------------------------------------------------------------
#
# getCurrTimeString
#
#---------------------------------------------------------------
sub getCurrTimeString ($) {
    my ($inTime) = @_;

    if (defined $inTime) {
	return getFullTimeString ($inTime);
    } elsif (defined $main::currTime) {
	return getFullTimeString ($main::currTime);
    } else {
	return getFullTimeString (localtime());
    }
}


#---------------------------------------------------------------
#
# padNum
#
# left pads the input number with 0's to bring it to $inPadSize
#
#---------------------------------------------------------------
sub padNum ($$) {
    my ($inNum, $inPadSize) = @_;
    my $retStr = '';
    my $currSize = 0;
    if (defined $inNum) {
	$currSize = length $inNum;
    }
    my $i = 0;
    for ($i = $currSize; $i < $inPadSize; $i++) {
	$retStr .= '0';
    }
    if (defined $inNum) {
	$retStr .= $inNum;
    }
    return $retStr;
}


#-----------------------------------------------------------------------
#
# stolen directly from "perldoc perlipc". Hey, it works!
#
# (this shouldn't get called if we're running windows...)
#
# I wonder how to make STDIN, STDOUT, and STDERR to to the
# logfile?
#
#-----------------------------------------------------------------------
sub daemonize () {

    # this breaks things because the logfile may not be open yet
    #
    #debugMessage ("Backgrounding via daemonize...\n", 1);
    chdir '/'               or die "daemonize - Can't chdir to /: $!";
    open STDIN, '/dev/null' or die "daemonize - Can't read /dev/null: $!";
    open STDOUT, '>/dev/null'
    	or die "daemonize - Can't write to /dev/null: $!";
    defined(my $pid = fork) or die "daemonize - Can't fork: $!";
    exit if $pid;
    setsid                  or die "daemonize - Can't start a new session: $!";
    open STDERR, '>&STDOUT' or die "daemonize - Can't dup stdout: $!";
}

#-----------------------------------------------------------------------
#
# returns the time of day in minutes
#
#-----------------------------------------------------------------------
sub getDayMinutes ($) {
    my ($inTime) = @_;
    my $sec = undef;
    my $min = undef;
    my $hour = undef;
    my $mday = undef;
    my $mon = undef;
    my $year = undef;
    my $wday = undef;
    my $yday = undef;
    my $isdst = undef;
    my $dayMinutes = 0;

    ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime ($inTime);

    $dayMinutes = $hour * 60 + $min;

    return $dayMinutes;
}

#--------------------------------------------------------------
#
#
#
#--------------------------------------------------------------
sub debugMessage ($$) {
    my ($inMessage, $inLevel) = @_;

    if (defined $inLevel) {
	if ($main::DEBUG_LEVEL >= $inLevel) {
	    if (defined ($main::logfile)) {
		print $main::logfile $inMessage;
	    } else {
		print $inMessage;
	    }
	    
	}
    } elsif ($main::DEBUG_LEVEL > 0) {
	if (defined ($main::logfile)) {
	    print $main::logfile $inMessage;
	} else {
	    print $inMessage;
	}
    }
}



return 1;










#---------------------------------
#
# Plain Old Documentation (pod...)
#
#---------------------------------

=pod

=head1 NAME

Karma - Oracle Database Monitor

=head1 DESCRIPTION

Karma is a multi-purpose database monitor which provides various
monitoring functionality to free the DBA from many day-to-day
monitoring tasks, allowing time to be spent on more in-depth
tuning and administration.

=head1 SYNOPSIS

This is the synopsis.

=head1 NOTES

Karma is made up of a number of different components.

need text based diagram here...


=head1 Main Components

=over 4

=item
o karmad

=item
o karmagentd

=item
o karmactl

=item
o karma.pm

=back

=head1 SQL

=over 4

=item
o karma_objs.sql

=item
o karma_user.sql

=back

=head1 Documentation

All documentation is available in pod format in the 'pod' directory.
From this common source, one can make text, html, man, and/or latex
documents suitable for printing.  This is recommended over printing
the html documents from a browser, as there may be issues with colors
and non-color printers.  In addition, an install_docs.pl script is
included which automates the generation of text documents for the
main karma install directory, as well as the base html document set.
Generally this is run before distribution.

=cut
