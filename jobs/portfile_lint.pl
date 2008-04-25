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
my $REPOHOST = "http://svn.macosforge.org/repository/macports";
my $SVNLOOK = "/opt/local/bin/svnlook";
my $PORTCMD = "/opt/local/bin/port";
my $SVN = "/opt/local/bin/svn -Nq --non-interactive";
my $MKDIR = "/bin/mkdir -p";


my $rev = $ARGV[0] or usage();
my $TMPROOT = "/tmp/mp_lint/$rev";

my @changes = `$SVNLOOK changed $REPOPATH -r $rev`;

my $author = `$SVNLOOK author $REPOPATH -r $rev`;
chomp($author);

_log("Rev: $rev");

foreach my $change (@changes) {
    if ($change =~ /Portfile/) { 
	# remove svn status and whitespace
	chop($change);
	$change =~ s/\w\s+([\/\w]+)/$1/g; 
	# extract the portname from parent dir of Portfile
	my $port = $change;
	$port =~ s/^.*\/([^\/]+)\/Portfile$/$1/g;

	# get the group directory
	my $group = $change;
	$group =~ s/^.*\/([^\/]+)\/[^\/]+\/Portfile$/$1/g;	

	_log("Port: $group / $port ");

	# make a temporary work area
	`$MKDIR $TMPROOT/$group/$port`;
	chdir("$TMPROOT/$group/$port") or die("Failed to change dir for port: $port");	
	`$SVN co $REPOHOST/trunk/dports/$group/$port/ .`;
	# test the port
	_lint($port);
    }
}


#
# Subroutines
#

sub _lint {
    my ($port) = @_; 
    my $errors = `$PORTCMD -qc lint 2>&1`;

    if ($errors) {
        _log("Error: $errors ");
	my $maintainers = `$PORTCMD -q info --maintainer $port`;
	# strip everything but the email addresses
	$maintainers =~ s/maintainer: //;
	$maintainers =~ s/openmaintainer\@macports.org//;
	$maintainers =~ s/nomaintainer\@macports.org//;
	chop($maintainers);

	_log("Maintainers: $maintainers ");

	_mail($port, $maintainers, $errors);
    }
}

sub _mail {
    my ($port, $maintainers, $errors) = @_;

    my %mail = (
	     To => "$author, $maintainers",
	     From => 'noreply@macports.org',
	     Subject => "[$rev] $port Lint Report",
	     Message => "Portfile: $port\n\n\n$errors \n\n",
	     smtp => 'relay.apple.com',
	     );

    _log("Mailto: $maintainers ");

    sendmail(%mail) or die $Mail::Sendmail::error;
}

sub _log {
	my ($errors) = @_;
	open(LOG, ">>$TMPROOT/errors") or return;
	print LOG "$errors\n";
	close(LOG);
}

sub usage {
	print "usage: portfile_lint.pl <rev>\n";
	exit();
}

