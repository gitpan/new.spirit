#!/usr/dim/perl/bin/perl

# $Id: nph-folder.cgi,v 1.8 2001/07/24 15:35:26 joern Exp $

use strict;
BEGIN {
	$| = 1;
	$0 =~ m!^(.*)[/\\][^/\\]+$!;    # Win32 Netscape Server Workaround
	chdir $1 if $1;
	require "../etc/default-user.conf";
	require "../etc/newspirit.conf"
}

require $CFG::objecttypes_conf_file;

use CGI qw(-nph);
use Carp;

use NewSpirit;
use NewSpirit::Folder;

my %METHOD = (
	edit => "edit_ctrl",
	create_folder => "create",
);

main: {
	# dieses globale Hash können Module nutzen, um request
	# spezifische Daten abzulegen
	%NEWSPIRIT::DATA_PER_REQUEST = ();
	
	my $q = new CGI;
	print $q->header( -nph => 1, -type=>'text/html' )
		unless $q->param('no_http_header');

	eval { main($q) };
	NewSpirit::print_error ($@) if $@;

	%NEWSPIRIT::DATA_PER_REQUEST = ();
}

sub main {
	my $q = shift;

	NewSpirit::check_session_and_init_request ($q);

	my $e = $q->param('e');
	
	# which method for this event?
	my $method = $METHOD{$e};

	if ( $method ) {
		my $o = new NewSpirit::Folder ($q);
		$o->$method();
	} elsif ( not $e ) {
		NewSpirit::blank_page();
	} else {
		print "event '$e' unknown";
	}
}
