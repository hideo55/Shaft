use strict;
use warnings;
use Test::More;
use Test::Exception;
use Scalar::Util ();
{
	package Foo;
	use Shaft;
	
	package Bar;
	use Shaft;

	has foo => ( is => 'rw', isa => 'Foo', weak_ref => 1 );
	has bar => ( is => 'rw', isa => 'Foo', default => sub{ Foo->new }, weak_ref => 1 );
	has baz => ( is => 'rw', isa => 'Foo|Int', default => 1, weak_ref => 1 );
	has qux => ( is => 'rw', isa => 'Foo|Int', pbp_style => 1, weak_ref => 1 );
}
my $foo = Foo->new;
my $bar = Bar->new( foo => $foo );
ok $bar->foo;
undef $foo;
ok !defined($bar->foo);
ok !defined($bar->bar);
is $bar->baz, 1;
$bar = Bar->new( baz => 10 );
is $bar->baz, 10;

$foo = Foo->new;
$bar->set_qux($foo);
ok $bar->get_qux;
undef $foo;
ok !$bar->get_qux;
$bar->set_qux(1);
ok $bar->get_qux;

Bar->meta->make_immutable;
$foo = Foo->new;
my $bar2 = Bar->new( foo => $foo );
ok $bar2->foo;
undef $foo;
ok !defined($bar2->foo);
ok !defined($bar2->bar);

done_testing;