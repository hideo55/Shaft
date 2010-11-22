use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warn;

{

	package Foo;
	use Shaft;

	has foo1 => ( is => 'rw', isa => 'ArrayRef',      => auto_deref => 1 );
	has foo2 => ( is => 'rw', isa => 'HashRef',       => auto_deref => 1 );
	has foo3 => ( is => 'rw', isa => 'ArrayRef[Int]', => auto_deref => 1 );
	has foo4 => ( is => 'rw', isa => 'HashRef[Int]',  => auto_deref => 1 );

	has foo5 => ( is => 'ro', isa => 'ArrayRef', auto_deref => 1 );
	has foo6 => ( is => 'ro', isa => 'HashRef', auto_deref => 1 );

}

my $foo = Foo->new(
	foo1 => [qw/foo bar baz/],
	foo2 => { foo => {}, bar => [], baz => 3},
	foo3 => [ 1 .. 10 ],
	foo4 => { foo => 1, bar => 2, baz => 3 },
	foo5 => [],
	foo6 => {},
);


ok ref($foo->foo1) eq 'ARRAY';
ok ref($foo->foo2) eq 'HASH';
ok ref($foo->foo3) eq 'ARRAY';
ok ref($foo->foo4) eq 'HASH';
ok ref($foo->foo5) eq 'ARRAY';
ok ref($foo->foo6) eq 'HASH';
ok $foo->meta->get_attribute('foo1')->should_auto_deref;
ok $foo->meta->get_attribute('foo2')->should_auto_deref;
ok $foo->meta->get_attribute('foo3')->should_auto_deref;
ok $foo->meta->get_attribute('foo4')->should_auto_deref;

my (@foo1,%foo2,@foo3,%foo4,@foo5,%foo6);

warning_is {
	@foo1 = $foo->foo1;
	%foo2 = $foo->foo2;
	@foo3 = $foo->foo3;
	%foo4 = $foo->foo4;
	@foo5 = $foo->foo5;
	%foo6 = $foo->foo6;
	
} undef;

is_deeply(\@foo1,[qw/foo bar baz/]);
is_deeply(\%foo2,{ foo => {}, bar => [], baz => 3});
is_deeply(\@foo3,[1..10]);
is_deeply(\%foo4,{ foo => 1, bar => 2, baz => 3 });

throws_ok{
	package Bar;
	use Shaft;
	
	has bar => ( auto_deref => 1 );
} qr/Can't auto-dereference without type constranint\('ArrayRef' or 'HashRef'\) on attribute \(bar\)/;

throws_ok{
	package Baz;
	use Shaft;
	
	has baz => ( isa => 'Int', auto_deref => 1 );
} qr/Can't auto-dereference anything other than a ArrayRef or HashRef on Attribute \(baz\)/;

done_testing;
