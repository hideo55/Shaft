use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warn;

{
	package Foo;
	use Shaft;
	
	has 'foo' => ( is => 'ro' );

	package Bar;
	use Shaft;

	has 'bar1' => ( is => 'ro' );
	has 'bar2' => ( is => 'rw', init_arg => undef );

	sub BUILDARGS {
		my $class = shift;
		my %args = @_;
		return \%args;
	}

	sub BUILD {
		my $self = shift;
		my $args = shift;
		$self->bar2($args->{BAR2}) if exists $args->{BAR2};
	}
}

isa_ok(Foo->new(),'Foo');
my $foo = Foo->new( foo => 1 );
is $foo->foo, 1;
$foo = Foo->new({ foo => 2 });
is $foo->foo, 2;
lives_ok{ $foo->new( foo => 3 ); };
my $foo2 = $foo->new( foo => 3 );
isa_ok $foo2, 'Foo';
is $foo2->foo, 3;
throws_ok {
	Foo->new([]);
} qr/^Single argment to new\(\) must be HASH reference/;

throws_ok {
	Foo->new(undef);
} qr/^Single argment to new\(\) must be HASH reference/;

is( Foo->can('new')->(), undef);

Foo->meta->make_immutable;

$foo = Foo->new( foo => 1 );
is $foo->foo, 1;
$foo = Foo->new({ foo => 2 });
is $foo->foo, 2;
lives_ok{ $foo->new( foo => 4 ); };
$foo2 = $foo->new( foo => 4 );
isa_ok $foo2, 'Foo';
is $foo2->foo, 4;
throws_ok {
	Foo->new([]);
} qr/^Single argment to new\(\) must be HASH reference/;
throws_ok {
	Foo->new(undef);
} qr/^Single argment to new\(\) must be HASH reference/;

is( Foo->can('new')->(),undef);


my $bar = Bar->new( bar1 => 10, bar2 => 10 );
is $bar->bar1,10;
is $bar->bar2,undef;
$bar = Bar->new( BAR2 => 5 );
is $bar->bar1,undef;
is $bar->bar2,5;

Bar->meta->make_immutable;

$bar = Bar->new( bar1 => 5, BAR2 => 10 );
is $bar->bar1,5;
is $bar->bar2,10;

throws_ok {
	$$bar = 0;
} qr/^Modification of a read-only value attempted/;

done_testing;
