# $Id: HTML.pm,v 1.14.2.1 2002/04/09 08:56:03 joern Exp $

package NewSpirit::CIPP::HTML;

$VERSION = "0.01";
@ISA = qw( 
	NewSpirit::CIPP::Prep
);

use strict;
use Carp;
use File::Copy;
use File::Basename;
use CIPP;
use NewSpirit::CIPP::Prep;

sub convert_meta_from_spirit1 {
	my $self = shift;
	
	my ($old_href, $new_href) = @_;
	
	$new_href->{use_strict} = ($old_href->{USE_STRICT} eq 'off' ? 0 : 1);
	
	1;
}

sub get_install_filename {
	my $self = shift;
	
	my $rel_path = "$self->{object_rel_dir}/$self->{object_basename}";
	
	$rel_path =~ s/\.[^\.]+$//;
	
	# strip 'cipp-' from the extension
	my $ext = $self->{object_ext};
	$ext =~ s/^cipp-//;
			
	my $path = "$self->{project_htdocs_dir}/$rel_path.$ext";
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
		
		$CIPP->{print_content_type} = 0;
		
		# was CIPP initialization OK?

		if ( !$CIPP->Get_Init_Status ) {
			push @{$self->{install_errors}->{other}},
			     "Unable to initialize CIPP preprocessor!";
			return;
		}

		$CIPP->Preprocess();

		close $fh;

		# update dependencies
		
		$self->build_module_dependencies($CIPP);
		
		my $dependencies = $CIPP->Get_Direct_Used_Objects;
		
		# HTML objects always depend on the base configuration
		$dependencies->{$CFG::default_base_conf.":cipp-base-conf"} = 1;
#		NewSpirit::dump($dependencies);
		
		$self->update_dependencies ( $dependencies );

		if ( ! $CIPP->Get_Preprocess_Status ) {
			# uh oh, errors! ;)
			$ok = 0;
			if ( $self->{command_line_mode} or $self->{dependency_installation} ) {
				$self->{install_errors}->{unformatted}
					= $CIPP->Get_Messages;
			} else {
				$self->{install_errors}->{formatted}
					= $CIPP->Format_Debugging_Source;
			}
		} else {
			my $to_file = $self->get_install_filename;

			# check Perl syntax, with execution and output
			# redirection to temporary HTML file
			my $tmp_html_file = "$CFG::OS_temp_dir/cipp$$.html";
			my $perl_errors = $self->check_for_perl_errors (
				dirname => dirname ($to_file),
				perl_code_sref => \$perl_code,
				fetch_output_file => $tmp_html_file,
			);
			
			open ($fh, "> /tmp/cippdebug");
			print $fh $perl_code;
			close $fh;

			if ( $perl_errors ) {
				# uh, oh, errors! :))
				$ok = 0;
				$self->{install_errors}->{perl} =
					$CIPP->Format_Perl_Errors(
						\$perl_code, \$perl_errors,
						$self->{command_line_mode}
					);
				unlink $tmp_html_file;
			} else {
				# OK, let's install the resulting HTML page
				# (move $tmp_html_file)

				if ( not move ($tmp_html_file, $to_file) ) {
					$ok = 0;
					push @{$self->{install_errors}->{other}},
						"Can't move '$tmp_html_file' to '$to_file'!";
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
