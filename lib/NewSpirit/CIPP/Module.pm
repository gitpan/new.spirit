# $Id: Module.pm,v 1.12 2001/03/05 17:11:32 joern Exp $

package NewSpirit::CIPP::Module;

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
use NewSpirit::LKDB;

sub get_install_filename {
	my $self = shift;
	
	my $meta_href = $self->get_meta_data;
	return if not $meta_href->{_pkg_name};

	my $rel_path = $meta_href->{_pkg_name};
	$rel_path =~ s!::!/!g;

	my $path = "$self->{project_lib_dir}/$rel_path.pm";
	
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
			undef, 1, 'cipp-module',
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

		$CIPP->Set_Write_Script_Header(0);
		$CIPP->Preprocess();

		close $fh;

		# update dependencies
		
		$self->build_module_dependencies ($CIPP);
		
		my $dependencies = $CIPP->Get_Direct_Used_Objects;
		$self->update_dependencies ( $dependencies );

		# check if module exists elsewhere
		$self->check_double_module_definition ($CIPP);

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
		} else {
			# ok, first check if the module name changed
			my $module_name = $CIPP->Get_Module_Name;
			
			if ( $meta->{_pkg_name} ne $module_name ) {
				# module name changed
				# lets delete the old module installation file
				my $old_inst_file = $self->get_install_filename;
				unlink $old_inst_file;

				# store the new module name
				$meta->{_pkg_name} = $module_name;
				$self->save_meta_data ($meta);
				
				# and create the path for the new module name
				$self->make_install_path;
			}

			# now install 
			my $to_file = $self->get_install_filename;

			# check Perl syntax
			my $perl_errors = $self->check_for_perl_errors (
				dirname        => dirname ($to_file),
				perl_code_sref => \$perl_code,
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

sub check_double_module_definition {
	my $self = shift;
	
	my ($CIPP) = @_;
	
	my $module_name = $CIPP->Get_Module_Name;
	
	my $module_file = new NewSpirit::LKDB ($self->{project_modules_file});
	my $href = $module_file->{hash};

	if ( $href->{$module_name} and $href->{$module_name} ne $self->{object} ) {
		my $object = $href->{$module_name};
		$object =~ s/\.([^.]+)$//;
		$object =~ s!/!.!g;
		$object = "$self->{project}.$object";
		$CIPP->Error ("MODULE", "Module '$module_name' is already defined in $object", -1);
	} else {
		$href->{$module_name} = $self->{object} if not $href->{$module_name};
	}
}

1;
