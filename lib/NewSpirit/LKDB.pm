
# $Id: LKDB.pm,v 1.18 2000/07/11 14:42:31 joern Exp $

package NewSpirit::LKDB;

$VERSION = "0.04";

use strict;
use FileHandle;
use Carp;
use Fcntl ':flock';

my $db_module;

BEGIN {
 	$db_module = $CFG::db_module || 'DB_File';
 	require "$db_module.pm";
}

sub new {
        my $type = shift;
        my ($filename) = @_;

        my $fh = new FileHandle();

	open ($fh, "> $filename.lck") or croak "can't write $filename.lck: $!";
	flock ($fh, LOCK_EX) or confess "can't flock $filename.lck: $!";

	my %hash;

	if ( $db_module eq 'GDBM_File' ) {
		tie ( %hash, 'GDBM_File',
		      $filename, &GDBM_File::GDBM_WRCREAT, 0666)
		or confess "can't tie $filename as GDBM: $!";
	} else {
		tie ( %hash, $db_module, 
		      $filename, O_CREAT|O_RDWR, 0660)
		or confess "can't tie $filename as $db_module: $!";
	}

        my $self = {
		filename => $filename,
		fh => $fh,
		hash => \%hash
	};

        return bless $self, $type;
}

sub DESTROY {
        my $self = shift;
	
	untie %{$self->{hash}} or confess "can't untie $self->{filename}: $!";
	flock ($self->{fh}, LOCK_UN) or confess "can't unlock $self->{filename}.lck: $!";
	close $self->{fh};
}

1;
