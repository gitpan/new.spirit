
# $Id: DataFile.pm,v 1.1 1999/09/14 15:21:43 joern Exp $

package NewSpirit::DataFile;

$VERSION = "0.01";
@ISA = qw( NewSpirit::LKFile );

use strict;
use Data::Dumper;
use NewSpirit::LKFile;
use Carp;

sub read {
	my $self = shift;

	my $data = $self->SUPER::read;

	my $href;
	{
		no strict;
		$href = eval $$data;
		croak "error reading DataFile: $@" if $@;
	}

	return $href;
}

sub write {
	my $self = shift;
	my ($href) = @_;
	
	my $data = Dumper ($href);
	
	$self->SUPER::write (\$data);

	1;
}

1;
