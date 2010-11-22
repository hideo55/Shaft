use strict;
use warnings;
use Test::More;
use Test::Exception;
{

	package Foo;
	use Shaft;

	has foo => (
		is      => 'rw',
		isa     => 'Int',
		default => 0,
		trigger => sub {
			my ( $self, $value ) = @_;
			$self->bar( $self->bar + $value );
		}
	);
	has bar => ( is => 'rw', isa => 'Int', default => 0 );

	has baz => (
		is => 'rw',
		default => 'a',
		pbp_style => 1,
		trigger => sub {
			my ($self, $value) = @_;
			$self->qux( 1 );
		}
	);

	has qux => (
		is => 'rw',
		default => 0,
	);

}

my $foo = Foo->new;

is $foo->foo,0;
is $foo->bar,0;
$foo->foo(2);
is $foo->foo,2;
is $foo->bar,2;
$foo->bar(1);
is $foo->foo,2;
is $foo->bar,1;
$foo->foo(10);
is $foo->foo,10;
is $foo->bar,11;
is $foo->qux, 0;
$foo->set_baz('b');
is $foo->get_baz, 'b';
is $foo->qux, 1;

my $foo2 = Foo->new( foo => 5, bar => 10, baz => 1 );
is $foo2->bar,15;
is $foo2->qux, 1;
Foo->meta->make_immutable;
my $foo3 = Foo->new( foo => 10, bar => 1 );
is $foo->bar,11;

ok $foo->meta->get_attribute('foo')->has_trigger;

throws_ok {
	package Bar;
	use Shaft;
	
	has bar => ( trigger => 'trigger' );
} qr/Trigger must be a CODE reference on attribute \(bar\)/;

done_testing;
