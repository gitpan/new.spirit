# $Id: Include.pm,v 1.13.2.1 2002/04/09 08:56:03 joern Exp $

package NewSpirit::CIPP::Include;

$VERSION = "0.01";
@ISA = qw(
	NewSpirit::CIPP::Prep
);

use strict;
use Carp;
use NewSpirit::CIPP::Prep;
use NewSpirit::PerlCheck;
use File::Basename;
use CIPP;

sub convert_meta_from_spirit1 {
	my $self = shift;
	
	my ($old_href, $new_href) = @_;
	
	$new_href->{use_strict} = ($old_href->{USE_STRICT} eq 'off' ? 0 : 1);
	
	1;
}

sub get_install_filename {
	my $self = shift;
	
	# actually no file is installed, this may change in future,
	# when preprocessed Includes may be cached in the filesystem
	
	return;
}

sub install_file {
	my $self = shift;

	my $meta = $self->get_meta_data;

	# read database hash (old style notation, for CIPP)
	my $databases_href = $self->get_old_style_databases;

	# determine default DB (old style notation, for CIPP)
	my $default_db = $self->get_old_style_default_database;
	
	# determine MIME Type and 'use strict' mode
	my $mime_type = $meta->{mime_type};
	my $use_strict = $meta->{use_strict};
	
	# this is for the generated Perl code
	my $perl_code;

	my $fh = new FileHandle;

	my $ok = 1;
	$self->{install_errors} = {};

	if ( open ($fh, "< $self->{object_file}") ) {
		my $CIPP = new CIPP (
			$fh, \$perl_code,
			{
				$self->{project} => "$self->{project_root_dir}/src"
			},
			$databases_href,
			$mime_type, $default_db, $self->{object_name},
			undef, 1, 'cipp',
			$use_strict, 0, undef,
			$self->{project},
			1, 'EN'
		);

		# was CIPP initialization OK?

		if ( !$CIPP->Get_Init_Status ) {
			push @{$self->{install_errors}->{other}},
			     "Unable to initialize CIPP preprocessor!";
			return;
		}

		# a Inclde needs no CGI or Database header code
		$CIPP->Set_Write_Script_Header(0);

		# preprocess the Include
		$CIPP->Preprocess();

		close $fh;

		# update dependencies
		$self->build_module_dependencies($CIPP);
		my $dependencies = $CIPP->Get_Direct_Used_Objects;
		$self->update_dependencies ( $dependencies );

		if ( ! $CIPP->Get_Preprocess_Status ) {
			# uh oh, errors! ;)
			$ok = 0;
			# if we are in a dependency installation, we
			# only give a brief list of the errors, and no
			# error highlighted version of the source code
			if ( $self->{command_line_mode} or $self->{dependency_installation} ) {
				$self->{install_errors}->{unformatted}
					= $CIPP->Get_Messages;
			} else {
				$self->{install_errors}->{formatted}
					= $CIPP->Format_Debugging_Source;
			}
		}
	} else {
		$ok = 0;
		push @{$self->{install_errors}->{other}},
			"Can't read '$self->{object_file}'!";
	}

	return $ok;
}

sub print_post_install_message {
	my $self = shift;
	
	print "<p>$CFG::FONT",
	      "<b>Include successfully preprocessed.</b>",
	      "</FONT><p>\n";

	1;
}

#sub get_dependant_objects {
#	my $self = shift;
#
#	my $depend = $self->get_depend_object;
#	
#	my %result;
#	$depend->get_dependants_resolved (
#		"$self->{object}:$self->{object_type}", \%result
#	);
#	
#	return \%result;
#}

1;
