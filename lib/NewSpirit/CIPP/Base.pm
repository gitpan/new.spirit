# $Id: Base.pm,v 1.20 2001/03/23 14:34:56 joern Exp $

package NewSpirit::CIPP::Base;

$VERSION = "0.01";
@ISA = qw( NewSpirit::Object::Record );

use strict;

my %FIELD_DEFINITION = (
	base_doc_url => {
		description => 'Document Mapping URL',
		type => 'text',
		check => "this.form.base_doc_url.value.substring(0,1)=='/'",
		alert => "Mappings must be a absolute URL",
	},
	base_cgi_url => {
		description => 'CGI Mapping URL',
		type => 'text',
		check => "this.form.base_cgi_url.value.substring(0,1)=='/'",
		alert => "Mappings must be a absolute URL",
	},
	base_error_show => {
		description => 'Show Perl / CIPP Error Messages',
		type => 'switch'
	},
	base_error_text => {
		description => 'User Friendly Error Message',
		type => 'textarea'
	},
	base_http_header => {
		description => 'Default HTTP Header<br>(Key Whitespace Value)',
		type => 'textarea'
	},
	base_default_db => {
		description => 'Default Database',
		type => 'method'
	},
	base_perl_lib_dir => {
		description => 'Additional Perl Library Directories<br>'.
			       '(Colon delimited)',
		type => 'text'
	},
	base_install_dir => {
		description => 'Local Installation Directory</b><br>'.
			       '(relative to local project root directory, '.
			       '<b>mandatory)',
		type => 'text'
	},
	base_prod_root_dir => {
		description => 'Project root directory of production system</b><br>'.
			       '(leave empty if this does not differ from<br>'.
			       'your local development system)<b>',
		type => 'text'
	},
	base_prod_shebang => {
		description => 'Shebang line of production system</b><br>'.
			       '(leave empty if this does not differ from<br>'.
			       'your local development system)<b>',
		type => 'text',
	},
	base_history_size => {
		description => "Object history limit (Default $CFG::default_history_size)",
		type => 'text 4',
	},
);

my @FIELD_ORDER_DEFAULT_CONFIG = (
	'base_doc_url', 'base_cgi_url', 'base_error_show',
	'base_error_text', 'base_http_header', 'base_perl_lib_dir',
	'base_default_db', 'base_history_size',
);

my @FIELD_ORDER_NON_DEFAULT_CONFIG = (
	'base_doc_url', 'base_cgi_url', 'base_error_show',
	'base_error_text', 'base_http_header',  'base_perl_lib_dir',
	'base_default_db', 'base_install_dir', 'base_prod_root_dir',
	'base_prod_shebang',
);
use Carp;
use NewSpirit::Object::Record;
use NewSpirit::Param1x;
use FileHandle;

sub init {
	my $self = shift;
	
	$self->{record_field_definition} = \%FIELD_DEFINITION;

	if ( $self->{object} eq $CFG::default_base_conf ) {
		# the default base configuration object has no
		# field for the production directory, this defaults
		# always to "$project_root_dir/prod"
		$self->{record_field_order} = \@FIELD_ORDER_DEFAULT_CONFIG;
	} else {
		$self->{record_field_order} = \@FIELD_ORDER_NON_DEFAULT_CONFIG;
	}
	
	1;
}

sub convert_data_from_spirit1 {
	my $self = shift;
	
	my ($object_file) = @_;
	
	my $fh = new FileHandle;
	
	open ($fh, $object_file)
		or croak "can't read $object_file";
	my $data = join ('', <$fh>);
	close $fh;
	
	my $old_data = NewSpirit::Param1x::Scalar2Hash ( \$data );
	
	my %data = (
		base_doc_url 	=> $old_data->{cipp_doc_url},
		base_cgi_url 	=> $old_data->{cipp_cgi_url},
		base_error_show	=> $old_data->{cipp_error_show},
		base_error_text	=> $old_data->{cipp_error_text}
	);

	my $df = new NewSpirit::DataFile ($object_file);
	$df->write (\%data);
	$df = undef;

	1;
}

sub property_widget_base_default_db {
	my $self = shift;
	
	my %par = @_;
	
	my $name = $par{name};
	my $data = $par{data_href};

	my $q = $self->{q};

	my $db_files = $self->get_databases;

	my @db_files = ('');
	my %labels = ( '' => 'none' );

	foreach my $db (sort keys %{$db_files}) {
		my $tmp = $db;
		$tmp =~ s!/!.!g;
		$tmp =~ s!\.cipp-db$!!;
		push @db_files, $db;
		$labels{$db} = "$self->{project}.$tmp";
	}

	print $q->popup_menu (
		-name => $name,
		-values => [ @db_files ],
		-default => $data->{$name},
		-labels => \%labels
	);

	print qq{<a href="$self->{object_url}&e=refresh_db_popup&next_e=edit"><b>Refresh Database Popup</b></a>},
}

sub get_install_filename {
	my $self = shift;

#	print "$self->{object} ne $self->{project_base_conf}<p>\n";

	return if $self->{object} ne $self->{project_base_conf};
	return $self->{project_config_dir}.'/cipp.conf';
}

sub install_file {
	my $self = shift;
	
	my $data = $self->get_data;
	
	# setup http header hash
	my $http_header = "( ";
	foreach my $line (split (/\n/, $data->{base_http_header})) {
		my ($key, $value) = split (/\s+/, $line, 2);
		$key =~ s/:$//;
		$key =~ s/'/\\'/g;
		$value =~ s/'/'\\'/g;
		$http_header .= "'$key' => '$value', ";
	}
	$http_header .= ")";

	my $fh = new FileHandle;
	my $install_file = $self->get_install_filename;
	
	return 1 if not $install_file;

	open ($fh, "> $install_file")
		or croak "can't write '$install_file'";

	my $base_doc_url = $data->{base_doc_url};
	my $base_cgi_url = $data->{base_cgi_url};
	$base_doc_url = "" if $base_doc_url eq '/';
	$base_cgi_url = "" if $base_cgi_url eq '/';

	my $perl_lib_code;
#	if ( $data->{base_perl_lib_dir} ) {
#		$perl_lib_code = "unshift (\@INC, '$data->{base_perl_lib_dir}');\n";
#	}

	my $base_perl_lib_dir = $data->{base_perl_lib_dir};
	$base_perl_lib_dir =~ s/:/ /g;

        if ( $self->{object} ne 'configuration.cipp-base-config' ) {
		# ok, we are an alternate base configuration
		my $prod_dir;
		if ( $data->{base_prod_root_dir} ) {
			$prod_dir = "$data->{base_prod_root_dir}/prod";
		} else {
			$prod_dir = NewSpirit::Object->new (
				q => $self->{q},
				object => $CFG::default_base_conf
			)->{project_prod_dir};
		} 

		my $cipp_project = $self->{project};

		print $fh <<__EOF;
package CIPP_Exec;
\$cipp_project     = '$cipp_project';
\$cipp_cgi_url     = '$base_cgi_url';
\$cipp_doc_url     = '$base_doc_url';
\$cipp_cgi_dir     = '$prod_dir/cgi-bin';
\$cipp_doc_dir     = '$prod_dir/htdocs';
\$cipp_config_dir  = '$prod_dir/config';
\$cipp_sql_dir     = '$prod_dir/sql';
\$cipp_log_file    = '$prod_dir/logs/cipp.log';
\$cipp_error_show  = '$data->{base_error_show}';
\$cipp_error_text  = q{$data->{base_error_text}};
\$cipp_url         = \$cipp_cgi_url;
\%cipp_http_header = $http_header;
\@cipp_perl_lib_dir = qw($base_perl_lib_dir);
1;
__EOF
	} else {
		# standard development environment
		print $fh <<__EOF;
package CIPP_Exec;
\$cipp_project     = '$self->{project}';
\$cipp_cgi_url     = '$base_cgi_url';
\$cipp_doc_url     = '$base_doc_url';
\$cipp_cgi_dir     = '$self->{project_cgi_base_dir}';
\$cipp_doc_dir     = '$self->{project_htdocs_base_dir}';
\$cipp_config_dir  = '$self->{project_config_dir}';
\$cipp_sql_dir     = '$self->{project_sql_dir}';
\$cipp_log_file    = '$self->{project_log_file}';
\$cipp_error_show  = '$data->{base_error_show}';
\$cipp_error_text  = q{$data->{base_error_text}};
\$cipp_url         = \$cipp_cgi_url;
\%cipp_http_header = $http_header;
\@cipp_perl_lib_dir = qw($base_perl_lib_dir);
1;
__EOF
	}
	close $fh;

	if ( $data->{base_default_db} ) {
		# if there is a default DB configuration,
		# we install it
		my $o = new NewSpirit::Object (
			q => $self->{q},
			object => $data->{base_default_db},
			base_config_object => $self->{project_base_conf}
		);
		$o->install_file;
	} else {
		# otherwise we delete the configuration
		# prod file, if it exists
		my $default_conf_file =
			"$self->{project_config_dir}/default.db-conf";
		unlink $default_conf_file
			if -f $default_conf_file;
	}

	1;
}

sub create {
	my $self = shift;
	
	# first create the object via the super class mechanism
	$self->SUPER::create;
	
	# now add a entry to the global databases file
	my $file = $self->{project_base_configs_file};
	
	my $df = new NewSpirit::DataFile ($file);
	my $data;
	eval {
		# existence of the file is not mandatory
		$data = $df->read;
	};
	$data->{$self->{object}} = 1;
	$df->write ($data);

	return;
}

sub delete {
	my $self = shift;
	
	# first delete the object via the super class mechanism
	$self->SUPER::delete;
	
	# no remove the entry from the global base configs file
	my $file = $self->{project_base_configs_file};
	
	my $df = new NewSpirit::DataFile ($file);
	my $data = $df->read;
	delete $data->{$self->{object}};
	$df->write ($data);

	return;
}

sub save_file {
	my $self = shift;

	my $q = $self->{q};
	
	my $base_doc_url = $q->param ('base_doc_url');
	my $base_cgi_url = $q->param ('base_cgi_url');

	# add a slash if the first character is no slash
	# (only absoulte URLs are allowed here)
	$base_doc_url =~ s!^([^/])!/$1!;
	$base_cgi_url =~ s!^([^/])!/$1!;

	# store the modified parameters back in the CGI object
	$q->param ('base_doc_url', $base_doc_url);
	$q->param ('base_cgi_url', $base_cgi_url);

	$self->SUPER::save_file;
}

1;