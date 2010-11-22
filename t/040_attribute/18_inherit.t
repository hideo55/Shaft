use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;
	
	has foo => ( is => 'rw' );

	has bar => ( is => 'ro', default => 1 );
	
	__PACKAGE__->meta->make_immutable;
	
	package Bar;
	use Shaft;
	extends 'Foo';
	
	has '+foo' => ( isa => 'Int', default => 0 );
	has '+bar' => ( default => 10 );
	
	__PACKAGE__->meta->make_immutable;
}

lives_ok{ Foo->new( foo => 'Str' ) };
dies_ok { Bar->new( foo => 'Str' ) };
lives_ok{ Bar->new( foo => 1 ) };
my $foo = Foo->new;
is $foo->foo,undef;
my $bar = Bar->new;
is $bar->foo,0;

ok !$foo->meta->get_attribute('foo')->has_default;
ok !$foo->meta->get_attribute('foo')->has_type_constraint;
ok $bar->meta->get_attribute('foo')->has_default;
ok $bar->meta->get_attribute('foo')->has_type_constraint;

throws_ok {
	package Baz;
	use Shaft;
	extends 'Foo';

	has '+foo' => ( 
	is => 'ro', 
	auto_deref => 1, 
	predicate => 'has_foo',
	clear => 1, 
	clearer => 'clear_foo',
	reset => 1,
	reseter => 'reset_foo',
	reader => 'get_foo',
	writer => 'set_foo', 
);
} qr/Illegal inherited options => /;

throws_ok {
	package Qux;
	use Shaft;
	extends 'Foo';

	Private '+foo' => ( lazy => 1 );
} qr/Can't override attribute option 'modifier'/;

throws_ok {
	package Hoge;
	use Shaft;
	
	package Fuaga;
	use Shaft;
	extends 'Hoge';
	
	has '+hoge' => ( default => 'hoge' );
} qr/Could't find an attribute 'hoge' from in inherit hierarchy/;

done_testing;
