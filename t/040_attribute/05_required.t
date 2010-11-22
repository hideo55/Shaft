use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;

{
	package Foo;
	use Shaft;
	has foo => ( is => 'rw', required => 1 );
}

lives_ok{ Foo->new( foo => 1 ) };
throws_ok { Foo->new } qr/^Attribute \(foo\) is required/;

ok( Foo->meta->get_attribute('foo')->is_required );

Foo->meta->make_immutable;

lives_ok{ Foo->new( foo => 1 ) };
throws_ok { Foo->new } qr/^Attribute \(foo\) is required/;

__END__