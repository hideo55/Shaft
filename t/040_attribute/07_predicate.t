use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;
	
	has foo => ( is => 'rw', predicate => 'has_foo', clearer => 'clear_foo' );
	has bar => ( is => 'rw', isa => 'Bool', predicate => 'is_set_bar' );

	Private baz => ( is => 'rw', predicate => 'has_baz' );
	Protected qux => ( is => 'rw', predicate => 'has_qux' );

	sub pri {
		shift->has_baz;
	}

	sub pro {
		shift->has_qux;
	}
	
}

my $foo = Foo->new;
ok !$foo->has_foo;
$foo->foo(1);
ok $foo->has_foo;
$foo->foo(undef);
ok $foo->has_foo;
$foo->clear_foo;
ok !$foo->has_foo;
ok !$foo->pri;
ok !$foo->pro;

can_ok $foo,'is_set_bar';

$foo = Foo->new( baz => 1, qux => 1 );
ok $foo->pri;
ok $foo->pro;

throws_ok {
	$foo->has_baz;
} qr/^has_baz\(\) is private method of Foo/;

throws_ok {
	$foo->has_qux;
} qr/^has_qux\(\) is protected method of Foo/;

done_testing;