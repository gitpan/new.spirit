# $Id: DataFile.pm,v 1.2 2001/03/23 14:34:56 joern Exp $

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
	if ( ref $href eq 'HASH' ) {
		# sort keys, otherwise output is not deterministic
		# which causes conflicts with files controlled by CVS
		$data =~ s/^.*\n//; 	# delete first line: $VAR1 = {
		$data =~ s/.*?\};\n$//;	# delete last line; };
		
		# sort lines
		$data = join ("\n", sort(split(/\n/, $data)));
		
		# add , to the line, which was the last one
		# (it may be moved to another position, so
		#  the comma is needed)
		$data =~ s/([^,])\n/$1,\n/;
		
		# construct data dump format
		$data = '$VAR1 = {'."\n".$data."\n        };\n";
	}
	
	$self->SUPER::write (\$data);

	1;
}

1;
