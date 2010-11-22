use strict;
use warnings;
use Test::More;
use Test::Exception;
{

	package Foo;
	use Shaft;
	use Shaft::Util::TypeConstraints;

	coerce 'ArrayRef' => from 'Int' =>via { [$_] };

	has foo1 => ( is => 'rw', default => 1, reseter => 'reset_foo1' );
	has foo2 => ( is => 'rw', default => sub { +{} }, reset => 1 );
	has foo3  => ( is => 'rw', isa => 'ArrayRef', builder => 'build_foo3', reset => 1, coerce => 1 );
	has _foo4 => ( is => 'rw', default => 1,            reset => 1 );
	has foo5 =>
		( is => 'rw', default => 1, reset => 1, reseter => '_reset_foo5' );

	Private foo6 => ( is => 'rw', default => 1, reset => 1 );
	Protected foo7 => ( is => 'rw', default => 1, reset => 1 );

	sub build_foo3 {
		2;
	}

	sub _foo6 {
		my ($self, $value) = @_;;
		if( $value ){
			$self->foo6($value);
		}else{
			$self->foo6;
		}
	}
	
	sub _foo7 {
		my ($self, $value) = @_;;
		if( $value ){
			$self->foo7($value);
		}else{
			$self->foo7;
		}
	}

	sub _reset_foo6 {
		shift->reset_foo6;
	}

	sub _reset_foo7 {
		shift->reset_foo7;
	}

}

my $foo = Foo->new;
$foo->foo1(10);
is $foo->foo1, 10;
can_ok $foo, 'reset_foo1';
$foo->reset_foo1;
is $foo->foo1, 1;

$foo->foo2->{test} = 1;
is $foo->foo2->{test}, 1;
can_ok $foo, 'reset_foo2';
$foo->reset_foo2;
ok !exists $foo->foo2->{test};

$foo->foo3(10);
is_deeply $foo->foo3, [10];
can_ok $foo, 'reset_foo3';
$foo->reset_foo3;
is_deeply $foo->foo3, [2];

can_ok( $foo, '_reset_foo4' );
can_ok( $foo, '_reset_foo5' );

is $foo->_foo6, 1;
is $foo->_foo7, 1;
is $foo->_foo6(10), 10;
is $foo->_foo7(5), 5;
$foo->_reset_foo6;
$foo->_reset_foo7;
is $foo->_foo6, 1;
is $foo->_foo7, 1;

throws_ok {
	$foo->reset_foo6;
} qr/^reset_foo6\(\) is private method of Foo/;

throws_ok {
	$foo->reset_foo7;
} qr/^reset_foo7\(\) is protected method of Foo/;

Foo->meta->add_method( build_foo3 => sub { +{} } );
throws_ok {
	$foo->reset_foo3;
} qr/^Attribute \(foo3\) does not pass the type constraint because:/;

throws_ok {

	package Bar;
	use Shaft;

	has foo => ( reseter => 'reset_foo' );
}
qr/^Can't use 'reseter' option for attribute \(foo\) without default_value\('default' or 'builder'\)/;

done_testing;
