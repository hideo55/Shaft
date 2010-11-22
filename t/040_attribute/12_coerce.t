use strict;
use warnings;
use Test::More;
use Test::Exception;
{
	package Foo;
	use Shaft;
	use Shaft::Util::TypeConstraints;
	
	coerce 'ArrayRef' => from 'Any' => via{ [$_] };
	coerce 'HashRef' 
	=> from 'Str' => via { +{ $_ => 1 } }
	=> from 'ArrayRef' => via { +{ map{ $_ => 1 } @$_ } };
	
	has foo => ( is => 'rw', isa => 'ArrayRef', coerce => 1 );
	has foo2 => ( is => 'rw', isa => 'ArrayRef' );
	has foo3 => ( is => 'rw' );
	has bar => ( is => 'rw', isa => 'HashRef', coerce => 1, pbp_style => 1 );
	has baz => ( is => 'rw', isa => 'HashRef', default => sub{ [qw/foo bar baz/]}, lazy => 1, coerce => 1 );

}

my $foo = Foo->new;
$foo->foo([1..5]);
is_deeply($foo->foo,[1..5]);
$foo->foo(100);
is_deeply($foo->foo,[100]);
$foo->foo({ test => 1 });
is_deeply($foo->foo,[{ test => 1 }]);
$foo->set_bar({ test => 1 });
is_deeply($foo->get_bar,{ test => 1 });
$foo->set_bar('str');
is_deeply($foo->get_bar,{ str => 1 });
$foo->set_bar([qw/foo bar baz/]);
is_deeply($foo->get_bar,{ foo => 1, bar => 1, baz => 1 });
is_deeply($foo->baz,{ foo => 1, bar => 1, baz => 1 });

ok $foo->meta->get_attribute('foo')->should_coerce;
ok $foo->meta->get_attribute('bar')->should_coerce;
ok $foo->meta->get_attribute('baz')->should_coerce;

ok !$foo->meta->get_attribute('foo2')->should_coerce;
throws_ok {
	$foo->foo2('str');
}qr/^Attribute \(foo2\) does not pass the type constraint because: Validation failed for 'ArrayRef' failed with value 'str'/;

is $foo->meta->get_attribute('foo3')->coerce_constraint('str'), 'str';

my $foo2 = Foo->new( foo => 100, bar => [qw/foo bar baz/] );
is_deeply($foo2->foo,[100]);
is_deeply($foo2->get_bar,{ foo => 1, bar => 1, baz => 1 });

Foo->meta->make_immutable;
my $foo3 = Foo->new( foo => 100, bar => [qw/foo bar baz/] );
is_deeply($foo3->foo,[100]);
is_deeply($foo3->get_bar,{ foo => 1, bar => 1, baz => 1 });

throws_ok {
	package Bar;
	use Shaft;
	
	has 'foo' => ( is => 'rw', coerce => 1 );
} qr/^You cannot have coercion without specifying a type constraint on attribute/;

done_testing;