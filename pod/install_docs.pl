#!/usr/bin/perl -w

#
# There's probably a better way, but for now, the quick and dirty.
#
use strict;
use Getopt::Std;

#
# subroutines 
#
#create_files (@);
#print_help ();
#verb_print ($);

$main::opt_h = undef;
$main::opt_v = undef;
$main::opt_n = undef;
getopts ('vhn:');

if (defined $main::opt_h) {
    print_help ();
}

if (defined $main::opt_n) {
    create_file ($main::opt_n);
} else {
    @main::Files = `ls *.pod`;
    create_files (@main::Files);
}

exit 1;

#----------------------------------------------------------------
#
# create_files
#
# create all the html and text documents from the .pod files
# in this directory
#
#----------------------------------------------------------------
sub create_files (@) {
    my (@inFiles) = @_;
    my $i = 0;
    my $theFile = undef;
    my $ucFile = undef;
    my $COMMAND = undef;

    while (defined $inFiles[$i]) {
	
	$theFile = $inFiles[$i];
	chomp ($theFile);
	$theFile =~ s/\.pod$//;
	$ucFile = uc $theFile;
	
	verb_print ("Creating $theFile.html...\n");
	$COMMAND = "pod2html $theFile.pod > ../doc_root/help/$theFile.html";
	system ($COMMAND);
	
	verb_print ("Creating $ucFile...\n");
	$COMMAND = "pod2text $theFile.pod > ../$ucFile";
	system ($COMMAND);
	
	$i++;
    }
}


#----------------------------------------------------------------
#
# create_file
#
# create the specified html & text doc from pod
#
#----------------------------------------------------------------
sub create_file ($) {
    my ($inFile) = @_;
    my $theFile = undef;
    my $ucFile = undef;
    my $COMMAND = undef;

    $theFile = $inFile;
    chomp ($theFile);
    $theFile =~ s/\.pod$//;
    $ucFile = uc $theFile;
    
    verb_print ("Creating $theFile.html...\n");
    $COMMAND = "pod2html $theFile.pod > ../doc_root/help/$theFile.html";
    system ($COMMAND);
    
    verb_print ("Creating $ucFile...\n");
    $COMMAND = "pod2text $theFile.pod > ../$ucFile";
    system ($COMMAND);
}

#----------------------------------------------------------------
#
# verb_print
#
#----------------------------------------------------------------
sub verb_print ($) {
    my ($inMessage) = @_;

    if (defined $main::opt_v) {
	print ($inMessage);
    }
}

#----------------------------------------------------------------
#
# print_help
#
#----------------------------------------------------------------
sub print_help () {
    print 
	"\n",
	" -h print help and exit\n",
	" -v verbose, print filenames while creating\n",
	" -n install named document (root only, w/o .pod extension)\n",
	"\n";

	exit 1;
}
