# $Id: Prep.pm,v 1.14 2001/02/28 16:55:06 joern Exp $

package NewSpirit::CIPP::Prep;

$VERSION = "0.01";
@ISA = qw ( NewSpirit::Object::Text );

#---------------------------------------------------------------------
# This module provides methods for preprocessing CIPP source to
# Perl code (e.g. NewSpirit::CIPP::CGI and NewSpirit::CIPP::Include
# use it).
#---------------------------------------------------------------------

use strict;
use Carp;
use NewSpirit::PerlCheck;
use NewSpirit::Object::Text;

sub get_meta_data {
	my $self = shift;

	# this overloading of Object::get_meta_data is a
	# workaround. Sometimes the use_strict field is
	# not inialized correct, so we do this here.
	
	my $meta = $self->SUPER::get_meta_data;
	
	if ( not defined $meta->{use_strict} ) {
		# uh oh, not defined, that is bad :(
		# Default is USE STRICT !!! ;)
		$meta->{use_strict} = 1;
		$self->save_meta_data ($meta);
	}
	
	return $meta;
}


sub get_old_style_databases {
	# this method returns the databases hash with the
	# old style object dot separated notation for the
	# object names. CIPP expects it in this format.

	my $self = shift;
	
	my $databases_href = $self->get_databases;
	
	my %hash;
	foreach my $k (keys %{$databases_href}) {
		my $new_k = $k;
		$new_k =~ s!\.[^\.]+$!!;
		$new_k =~ s!/!.!g;
#		$new_k = "x.$new_k";
		$hash{$new_k} = $databases_href->{$k};
	}
	
	my $default_db = $self->get_default_database;
	
	if ( $default_db ) {
		$hash{default} = "CIPP::DB_DBI";
	}
	
	return \%hash;
}

sub get_old_style_default_database {
	# this method returns the default database in the
	# old style object dot separated notation.
	# CIPP expects it in this format.

	my $self = shift;
	
	my $default_db = $self->get_default_database;
	return "" if not $default_db;

	$default_db =~ s!\.[^\.]+$!!;
	$default_db =~ s!\.!_!g;
	$default_db = $self->{project}.".$default_db";

	return $default_db;	
}

sub print_pre_install_message {
	my $self = shift;
	
	print "<p>$CFG::FONT CIPP Preprocessing in progress...</FONT><p>\n";

	1;
}

sub print_install_errors {
	my $self = shift;

	my ($errors) = @_;
	
	my $head = qq{$CFG::FONT<FONT COLOR="red">}.
		   qq{<b>There are \%s errors:</b>}.
		   qq{</FONT>%s</FONT><p>\n};

	if ( $errors ) {
		# if $errors is given, we assume to be used for printing
		# the error summary for a dependency installation, so
		# the "There are bla errors" header is omitted.
		$head = '';
	}

	$errors ||= $self->{install_errors};

	if ( ref $errors eq 'ARRAY' ) {
		$self->SUPER::print_install_errors(@_);
		return 1;
	}

#	use Data::Dumper;print "<pre>",Dumper($errors),"</pre>\n";

	if ( $errors->{formatted} ) {
		# formatted preprocessor errors
		printf ($head, 'CIPP preprocessor');

		print <<__HTML;
<FONT SIZE="$CFG::FONT_SIZE">
${$errors->{formatted}}
</FONT>
__HTML
	}
	
	if ( $errors->{perl} ) {
		# Perl syntax errors!
		printf (
			$head,
			'Perl syntax',
			qq{ <b><a href="$self->{object_url}&e=function&f=show_perl">}.
			qq{[Show Perl Source]}.
			qq{</a></b>}.
			qq{ <b><a href="$self->{object_url}&e=function&f=download_perl&no_http_header=1">}.
			qq{[Download]}.
			qq{</a></b>}
		);

		my $errors = ${$errors->{perl}};
		$errors =~ s/\n/<p>/g;

		print <<__HTML;
<FONT SIZE="$CFG::FONT_SIZE">
<tt>
$errors
</tt>
</FONT>
__HTML
	}
	
	if ( $errors->{perl_unformatted} ) {
		printf ($head, 'Perl syntax');
		print <<__HTML;
<table border=1 width="100%">
<tr bgcolor="#555555">
  <td>$CFG::FONT<font color="white"><b>Unformatted Perl Error Messages</b></FONT></FONT></td>
</tr>
<tr>
  <td>$CFG::FONT${$errors->{perl_unformatted}}</font></td>
</tr>
</table>
__HTML
	}

	if ( $errors->{unformatted} ) {
		# Unformatted CIPP errors
		printf ($head, 'CIPP preprocessor');
		print <<__HTML;
<table border=1 width="100%">
<tr bgcolor="#555555">
  <td width="10%">$CFG::FONT<font color="white"><b>Line</b></FONT></FONT></td>
  <td width="90%">$CFG::FONT<font color="white"><b>Message</b></FONT></FONT></td>
</tr>
__HTML

		my @bgcolor = (
			'bgcolor="#eeeeee"',
			'bgcolor="#dddddd"',
		);
		my $idx = 0;

		foreach my $err ( @{$errors->{unformatted}} ) {
			my @e = split ('\t', $err, 3);
			my $include;
			my $rowspan = 1;
			++$idx;
			$idx = 0 if $idx == 2;
			if ( $e[0] =~ /:/ ) {
				# ok, we have a path of objects here,
				# delimited by colons. Let's determine
				# the Include, which throws this error
				$e[0] =~ /:([^:]+)$/;
				$include = "In Include: <b>$1</b></font></td><tr $bgcolor[$idx]><td>$CFG::FONT\n";
				$rowspan = 2;
			}
			print (
				"<tr $bgcolor[$idx]><td valign=top rowspan=$rowspan>$CFG::FONT$e[1]</td>",
				"<td valign=top>$CFG::FONT$include$e[2]</td></tr>\n"
			);
		}
		print "</tr></table>\n";
	}

	if ( $errors->{other} ) {
		# Other errors
		printf ($head, 'installation');
		print <<__HTML;
<FONT SIZE="$CFG::FONT_SIZE"><pre>
__HTML
		print join ("\n", @{$errors->{other}});
		print "</pre></FONT>\n";
	}

	1;
}

sub function_ctrl {
	my $self = shift;
	
	my $q = $self->{q};
	my $f = $q->param('f');
	
	if ( $f eq 'show_perl' ) {
		$self->object_header ("Show Perl Code");
		$self->install_file;
		
		${$self->{_perl_code}} =~ s/</&lt;/g;
		
		print "<font size=$CFG::FONT_SIZE><tt><pre>";
		print ${$self->{_perl_code}};
		print "</tt></pre></font>\n";

		NewSpirit::end_page();
	} elsif ( $f eq 'download_perl' ) {
		$self->install_file;
		my $mime_type = $self->{object_type_config}->{mime_type};
		print $q->header(
			-nph => 1,
			-type => $mime_type,
			-Pragma => 'no-cache',
			-Expires => 'now'
		);
		print ${$self->{_perl_code}};
	}
}

sub create {
	my $self = shift;
	
	$self->SUPER::create;
	
	my $meta_href = $self->get_meta_data;
	$meta_href->{use_strict} = 1;
	$self->save_meta_data ($meta_href);
	
	return;
}

sub build_module_dependencies {
	my $self = shift;
	
	my ($CIPP) = @_;
	
	my $used_modules = $CIPP->Get_Used_Modules;
	return if not $used_modules;
	
	my $module_file = new NewSpirit::LKDB ($self->{project_modules_file});
	my $href = $module_file->{hash};

	foreach my $module ( keys %{$used_modules} ) {
		my $object_file = $href->{$module};
		my $object_type = $self->get_object_type($object_file);
		$CIPP->Set_Direct_Used_Object ($object_file, $object_type);
	}

	1;
}

sub check_for_perl_errors {
	my $self = shift;
	
	my %par = @_;
	
	my $dirname           = $par{dirname};
	my $perl_code_sref    = $par{perl_code_sref};
	my $fetch_output_file = $par{fetch_output_file};

	# We restrict the number of checks which one perlcheck.pl
	# process performs to 20 - otherwise the process may consumpt
	# to much memory.

	++$NEWSPIRIT::DATA_PER_REQUEST{prep_perl_check_instance_cnt};

	if ( $NEWSPIRIT::DATA_PER_REQUEST{prep_perl_check_instance_cnt} == 20 ) {
		$NEWSPIRIT::DATA_PER_REQUEST{prep_perl_check_instance_cnt} = 0;
		$NEWSPIRIT::DATA_PER_REQUEST{prep_perl_check_instance} = undef;
	}

	my $pc = $NEWSPIRIT::DATA_PER_REQUEST{prep_perl_check_instance};

	if ( not $pc ) {
		$NEWSPIRIT::DATA_PER_REQUEST{prep_perl_check_instance_cnt} = 0;
		$NEWSPIRIT::DATA_PER_REQUEST{prep_perl_check_instance}
			= $pc = new NewSpirit::PerlCheck ();
	}

	$pc->set_directory ( $dirname );
	
	my $rc;
	if ( $fetch_output_file ) {
		$rc = $pc->execute (
			$perl_code_sref, $fetch_output_file
		);
	} else {
		$rc = $pc->check ($perl_code_sref);
	}
	
	return $rc;
}

1;


