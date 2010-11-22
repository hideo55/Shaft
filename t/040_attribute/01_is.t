use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;

	has rw => ( is      => 'rw' );
	has ro => ( is      => 'ro' );
}

my $foo = Foo->new( ro => 1 );

is $foo->rw, undef;
is $foo->rw(1), 1;
is $foo->rw, 1;
is $foo->ro, 1;
throws_ok{ $foo->ro(2) } qr/Can't modify read-only attribute \(ro\)./;

ok($foo->meta->get_attribute('ro')->is_ro,'is_ro');
ok(!$foo->meta->get_attribute('rw')->is_ro,'is_ro');
ok(!$foo->meta->get_attribute('ro')->is_rw,'is_rw');
ok($foo->meta->get_attribute('rw')->is_rw,'is_rw');
is $foo->meta->get_attribute('ro')->access_type, 'ro';
is $foo->meta->get_attribute('rw')->access_type, 'rw';

Foo->meta->add_attribute( foo => { is => 'ro' } );
$foo = Foo->new( foo => 1 );
is $foo->foo,1;
Foo->meta->remove_attribute('foo');

Foo->meta->make_immutable;
Foo->meta->add_attribute( bar => { is => 'ro' } );
my $foo2 = Foo->new( ro => 1, rw => 2, bar => 1 );
is $foo2->ro,1;
is $foo2->rw,2;
is $foo2->rw(10), 10;
is $foo2->rw, 10;
is $foo2->bar, undef;

throws_ok{ $foo->ro(1) } qr/Can't modify read-only attribute \(ro\)./;

done_testing;