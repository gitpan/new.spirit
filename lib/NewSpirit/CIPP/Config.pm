# $Id: Config.pm,v 1.9 2001/02/14 16:53:00 joern Exp $

package NewSpirit::CIPP::Config;

$VERSION = "0.01";
@ISA = qw(
	NewSpirit::CIPP::Prep
	NewSpirit::CIPP::ProdReplace
);

use strict;
use Carp;
use NewSpirit::CIPP::Prep;
use NewSpirit::CIPP::ProdReplace;
use NewSpirit::PerlCheck;
use File::Basename;
use FileHandle;

sub get_install_filename {
	my $self = shift;
	
	# this method comes from ProdReplace. It may return
	# another object name as the installation target
	my $filename = $self->get_install_object_name;
	return if not $filename;

	$filename = "$filename.config";

	# remove projekt name
	$filename =~ s/^.*?\.//;

	return "$self->{project_config_dir}/$filename";
}

sub print_pre_install_message {
	my $self = shift;
	
	print "<p>$CFG::FONT Perl syntax checking in progress...</FONT><p>\n";

	1;
}

sub install_file {
	my $self = shift;

	return 1 if not $self->installation_allowed;	# prod replace

	my $perl_code_sref = $self->get_data;

	# check Perl syntax
	$$perl_code_sref = "no strict;\n".$$perl_code_sref;

	my $perl_errors = $self->check_for_perl_errors (
		dirname => $self->{project_config_dir},
		perl_code_sref => $perl_code_sref,
	);

	$self->{install_errors} = {};
	my $ok = 1;
	if ( $perl_errors ) {
		# uh, oh, errors! :))
		$ok = 0;

		$self->{install_errors}->{perl_unformatted} = \$perl_errors;

	} else {
		# OK, let's install the config file
		my $to_file = $self->get_install_filename;
		return 1 if not $to_file;

		my $fh = new FileHandle;
		my ($success, $message);
		if ( open ($fh, "> $to_file") ) {
			print $fh $$perl_code_sref;
			close $fh;
			chmod 0664, $to_file;
		} else {
			push @{$self->{install_errors}->{other}},
				"Can't write '$to_file'!";
		}
	}

	return $ok;
}

1;
