use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
{
	package Shaft::Meta::Attribute::Custom::Foo1;
	use Shaft -extends => 'Shaft::Meta::Attribute';

	no Shaft;
	__PACKAGE__->meta->make_immutable;
	package Foo;
	use Shaft;

	has foo => ( is => 'rw', metaclass => 'Foo1' );

	no Shaft;
	__PACKAGE__->meta->make_immutable;
}

my $attr = Foo->meta->get_attribute('foo');
isa_ok $attr,'Shaft::Meta::Attribute::Custom::Foo1';

dies_ok{
	package Bar;
	use Shaft;

	has bar => ( is => 'rw', traits => [qw/Class::NOT::EXIST/] );
};

throws_ok {
	package Baz;
	use Shaft;
	
	has baz => ( is => 'rw', metaclass => 'Foo' );
} qr/^You must supply the class name that inheritance of 'Shaft::Meta::Attribute' to the 'metaqclass' option/;

__END__
