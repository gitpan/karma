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
# karma.pm
#
# common code for karmad, karmagentd, karmactl
#
#------------------------------------------------------------------

use POSIX 'setsid';

sub getTimeString ($);
sub print_warranty ();
sub print_version ();
sub log_message ($);
sub log_message_wtime ($);
sub debug_print ($$);
sub getDayMinutes ($);

#
# current version
#
$main::VERSION="0.9.0";
$main::DEBUG_LEVEL = 0;



#-----------------------------------------------------------------------
#
# print version and exit
#
#-----------------------------------------------------------------------
sub print_version () {
    print 
	"\n",
	"  Karma v$main::VERSION Copyright (C) 1999 Sean Hull <shull\@pobox.com>\n",
	"  Karma comes with ABSOLUTELY NO WARRANTY; for details\n",
	"  type \"karmad -w\".  This is free software, and you are\n",
	"  welcome to redistribute it under certain conditions.\n";

    exit ;
}


#-----------------------------------------------------------------------
#
# GNU General Public License Warranty
#
#-----------------------------------------------------------------------
sub print_warranty () {
    print 
	"\n",
	"   Copyright (C) 1999  Sean Hull <shull\@pobox.com>\n",
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
sub log_message ($) {
    my ($message) = @_;

    if (defined ($logfile)) {
	print $logfile ($message);
    }
}

#-----------------------------------------------------------------------
#
# log a message with a timestamp
#
# should this use $currTime??
#
#-----------------------------------------------------------------------
sub log_message_wtime ($) {
    my ($inMessage) = @_;

    my $theTimeStr = getCurrTimeStr ();
    log_message ("$theTimeStr - $inMessage");
}


#-----------------------------------------------------------------------
#
# convert the given time to a string
#
#-----------------------------------------------------------------------
sub getTimeString ($) {
    my ($inTime) = @_;

    my $timeStr = "";
    my $hourStr = "";
    my $sec =  $min = $hour = $mday = $mon = 
       $year = $wday = $yday = $isdst = 0;


    #
    # get the time and break it into it's components
    #
    ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime ($inTime);

    #
    # adjust minutes, or just put hour and minutes together for time
    # string
    #
    if ($hour < 10) {
	$hourStr = "0$hour";
    } else {
	$hourStr = "$hour";
    }
    if ($min < 10) {
	$timeStr = "$hourStr:0$min";
    } else {
	$timeStr = "$hourStr:$min";
    }

    return $timeStr;
}

sub getCurrTimeStr () {
    my ($inTime) = @_;

    if (defined $inTime) {
	return getTimeString ($inTime);
    } elsif (defined $main::currTime) {
	return getTimeString ($main::currTime);
    } else {
	return "";
    }
}

#-----------------------------------------------------------------------
#
# stolen directly from "perldoc perlipc". Hey, it works!
#
#-----------------------------------------------------------------------
sub daemonize () {
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


    my $sec =  $min = $hour = $mday = $mon = 
       $year = $wday = $yday = $isdst = 0;
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
sub debug_print ($$) {
    my ($inMessage, $inLevel) = @_;

    if (defined ($inLevel)) {
	if ($main::DEBUG_LEVEL >= $inLevel) {
	    print $inMessage;
	}
    } elsif ($main::DEBUG_LEVEL > 0) {
	print ("$inMessage\n");
    }
}



return 1;










