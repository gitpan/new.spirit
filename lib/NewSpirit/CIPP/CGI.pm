# $Id: CGI.pm,v 1.19 2001/03/05 17:11:32 joern Exp $

package NewSpirit::CIPP::CGI;

$VERSION = "0.01";
@ISA = qw(
	NewSpirit::CIPP::Prep
);

use strict;
use Carp;
use NewSpirit::CIPP::Prep;
use NewSpirit::PerlCheck;
use File::Basename;
use CIPP 2.27;

sub convert_meta_from_spirit1 {
	my $self = shift;
	
	my ($old_href, $new_href) = @_;
	
	$new_href->{mime_type} = $old_href->{MIME_TYPE};
	$new_href->{use_strict} = ($old_href->{USE_STRICT} eq 'off' ? 0 : 1);
	
	1;
}

sub get_install_filename {
	my $self = shift;
	
	my $rel_path = "$self->{object_rel_dir}/$self->{object_basename}";
	
	$rel_path =~ s/\.[^\.]+$//;
	my $path = "$self->{project_cgi_dir}/$rel_path.cgi";
	
	$path =~ s!/+!/!g;
	
	return $path;
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

	$self->{install_errors} = {};
	my $ok = 1;

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

		$CIPP->Preprocess();

		close $fh;

		# update dependencies
		
		$self->build_module_dependencies ($CIPP);
		
		my $dependencies = $CIPP->Get_Direct_Used_Objects;
		
		$self->update_dependencies ( $dependencies );

		if ( ! $CIPP->Get_Preprocess_Status ) {
			# uh oh, errors! ;)
			$ok = 0;
			# if we are in a dependency installation, we
			# only give a brief list of the errors, and no
			# error highlighted version of the source code
			if ( $self->{dependency_installation} ) {
				$self->{install_errors}->{unformatted}
					= $CIPP->Get_Messages;
			} else {
				$self->{install_errors}->{formatted}
					= $CIPP->Format_Debugging_Source;
			}
#			use Data::Dumper;print "<pre>", Dumper($self->{install_errors}),"</pre>\n";
		} else {
			my $to_file = $self->get_install_filename;

			# check Perl syntax
			my $perl_errors = $self->check_for_perl_errors (
				dirname        => dirname ($to_file),
				perl_code_sref => \$perl_code
			);

			if ( $perl_errors ) {
				# uh, oh, errors! :))
				$ok = 0;
				$perl_code =~ s/^.*\n//;
				$perl_code =~ s/^.*\n//;

				if ( $self->{dependency_installation} ) {
					$self->{install_errors}->{perl_unformatted}
						= \$perl_errors;
				} else {
					$self->{install_errors}->{perl} =
						$CIPP->Format_Perl_Errors (
							\$perl_code, \$perl_errors
						);
				}
				
				open ($fh, "> /tmp/cippdebug");
				print $fh $perl_code;
				close $fh;
			} else {
				# OK, let's install the resulting Perl program
				my ($success, $message);

				if ( open ($fh, "> $to_file") ) {
					print $fh $perl_code;
					close $fh;
					chmod 0775, $to_file;
				} else {
					push @{$self->{install_errors}->{other}},
						"Can't write '$to_file'!";
				}
			}
		}
	} else {
		$ok = 0;
		push @{$self->{install_errors}->{other}}, "Can't read '$self->{object_file}'!";
	}

	$self->{_perl_code} = \$perl_code;

	return $ok;
}

1;
