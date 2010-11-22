use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo::Role;
	use Shaft::Role;

	package Bar;
	use Shaft;
	with 'Foo::Role';

	package Baz;
	use Shaft;

	package Foo;
	use Shaft;
	use Shaft::Util::TypeConstraints;
	Public foo => ( is => 'rw', does => 'Foo::Role' );
	Public bar => ( is => 'rw', does => find_type_constraint('Foo::Role') );

}

my $foo = Foo->new;
my $bar = Bar->new;
my $baz = Baz->new;

#does
lives_ok { $foo->foo($bar) };
dies_ok { $foo->foo($baz) };
lives_ok { $foo->bar($bar) };
dies_ok { $foo->bar($baz) };

lives_ok { Foo->new( foo => $bar, bar => $bar ) };
dies_ok { Foo->new( foo => $bar, bar => $baz ) };
Foo->meta->make_immutable;
lives_ok { Foo->new( foo => $bar, bar => $bar ) };
dies_ok { Foo->new( foo => $bar, bar => $baz ) };

lives_ok {
	package Hoge;
	use Shaft;
	
	Public 'hoge' => ( isa => 'Bar', does => 'Foo::Role' );
};

throws_ok {
	package Fuga;
	use Shaft;
	
	Public 'fuga' => ( isa => 'Baz', does => 'Foo::Role' );
} qr/^Can't have an isa option and a does option if the isa does not do the does on attribute/;

throws_ok {
	package Piyo;
	use Shaft;
	
	Public 'piyo' => ( isa => 'NONE', does => 'Foo::Role' );
} qr/^Can't have an isa option which can't ->does\(\) on attribute/;

lives_ok {
	package Piyo2;
	use Shaft;
	has piyo2 => ( is => 'rw', does => 'PiyoPiyo' );
};
my $tc = Shaft::Util::TypeConstraints::find_type_constraint('PiyoPiyo');
ok $tc;
ok $tc->is_subtype_of('Object');

throws_ok {
	package Piyo3;
	use Shaft;
	has piyo3 => ( is => 'rw', does => $foo );
} qr/contains invalid characters for a type name/;

done_testing;
