# $Id: DataFile.pm,v 1.3.2.1 2003/08/07 08:12:52 joern Exp $

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
		croak "error reading DataFile '$self->{filename}': $@" if $@;
	}

	return $href;
}

sub write {
	my $self = shift;
	my ($href) = @_;
	
	my $data;
	if ( ref $href eq 'HASH' ) {
		my @list;
		foreach my $key ( sort keys %{$href} ) {
			push @list, $key, $href->{$key};
		}
		$data = Dumper (\@list);
		$data =~ s/\[/{(/;
		$data =~ s/];\n$/)};\n/;
	} else {
		$data = Dumper ($href);
	}

	$self->SUPER::write (\$data);

	1;
}

1;
