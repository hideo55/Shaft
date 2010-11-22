use strict;
use warnings;

use Test::More tests => 1;
use Test::Exception;

use Shaft::Meta::Class;

TODO:{
	my $meta;
	lives_ok {
		$meta = Shaft::Meta::Class->create_anon_class(
			superclasses => [qw/Shaft::Object/],
		);
	} 'Class is created successfully';
}

__END__