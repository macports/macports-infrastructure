#!/opt/local/bin/perl -w

####
# Run "port lint" for all Portfiles changed in a given revision
# Created by William Siegrist,
# e-mail: wsiegrist@apple.com
# $Id$
####

use strict;
use Mail::Sendmail;

my $REPOPATH = "/svn/repositories/macports/";
my $SVNLOOK = "/opt/local/bin/svnlook";
my $PORTCMD = "/opt/local/bin/port";

my $rev = $ARGV[0] or usage();
my @changes = `$SVNLOOK changed $REPOPATH -r $rev`;

foreach my $change (@changes) {
    if ($change =~ /Portfile/) { 
	# remove svn status and whitespace
	chop($change);
	$change =~ s/\w\s+([\/\w]+)/$1/g; 
	# extract the portname from parent dir of Portfile
	my $port = $change;
	$port =~ s/^.*\/([^\/]+)\/Portfile$/$1/g;

	# test the port
	_lint($port);
    }
}


#
# Subroutines
#

sub _lint {
    my ($port) = @_; 
    my $errors = `sudo $PORTCMD -q lint $port`;
    if ($errors) {
	my $maintainers = `$PORTCMD -q info --maintainer $port`;
	# strip everything but the email addresses
	$maintainers =~ s/maintainer: //;
	$maintainers =~ s/openmaintainer\@macports.org//;
	$maintainers =~ s/nomaintainer\@macports.org//;
	chop($maintainers);

	_mail($port, $maintainers, $errors);
    }
}

sub _mail {
    my ($port, $maintainers, $errors) = @_;

    my %mail = (
	     To => $maintainers,
	     From => 'noreply@macports.org',
	     Subject => "[MacPorts Lint] Portfile Lint Errors for: $port",
	     Message => "Portfile: $port \n\n\n Errors: $errors \n\n",
	     smtp => 'relay.apple.com',
	     );

    sendmail(%mail) or die $Mail::Sendmail::error;
}

sub usage {
	print "usage: portfile_lint.pl <rev>\n";
	exit();
}




