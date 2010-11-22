use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warn;

{

	package Foo;
	use Shaft;

	Public foo => ( is => 'ro', isa => 'Int' );

	__PACKAGE__->meta->make_immutable;

}

my $meta = Foo->meta;
ok !$meta->is_mutable;
ok $meta->has_method('new');
ok $meta->has_method('DESTROY');
isa_ok $meta->get_method('new'),     'Shaft::Meta::Method::Constructor';
isa_ok $meta->get_method('DESTROY'), 'Shaft::Meta::Method::Destructor';

Foo->meta->add_attribute( bar => { is => 'rw' } );

my $foo = Foo->new( foo => 1, bar => 2 );
is $foo->foo, 1;
is $foo->bar, undef;

$meta->make_mutable;
ok $meta->is_mutable;
ok !$meta->has_method('new');
ok !$meta->has_method('DESTROY');
is $meta->make_mutable, 1;

my $foo2 = Foo->new( foo => 3, bar => 4 );
is $foo2->foo, 3;
is $foo2->bar, 4;

Foo->meta->make_immutable( 
		inline_constructor => 1,
		inline_destructor  => 1
);

my $foo3 = Foo->new( foo => 5, bar => 6 );
is $foo3->foo, 5;
is $foo3->bar, 6;

is( Foo->meta->make_immutable, 1 );

warning_like {

	package Bar;
	use Shaft;

	sub new {
	}

	__PACKAGE__->meta->make_immutable;
} qr/^Not inlining a constructor for Bar/;


warning_like{

	package Baz;
	use Shaft;

	sub DESTROY {
	}

	__PACKAGE__->meta->make_immutable;
} qr/^Not inlining a destructor for Baz/;


warning_is{
	package Hoge;
	use Shaft;

	sub new {

	}

	sub DESTROY {
	}

	__PACKAGE__->meta->make_immutable(
		inline_constructor => 0,
		inline_destructor  => 0
	);
} undef;

done_testing;
