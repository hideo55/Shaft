use strict;
use warnings;
use Test::More;
use Test::Exception;
{
	package Foo;
	use Shaft;
	Public 'foo1';
	Protected 'foo2';
	Private 'foo3';

	Public public_rw          => ( is      => 'rw' );
	Public public_ro          => ( is      => 'ro' );
	Public public_a          => ( is      => 'rw', pbp_style => 1 );

	Private private_ro => ( is => 'ro' );
	Private private_rw => ( is => 'rw' );
	Private private_a => ( is => 'rw', pbp_style => 1 );

	Protected protected_ro => ( is => 'ro' );
	Protected protected_rw => ( is => 'rw' );
	Protected protected_a => ( is => 'rw', pbp_style => 1 );

}

my $foo = Foo->new;
ok $foo->meta->get_attribute('foo1')->is_public;
ok $foo->meta->get_attribute('foo2')->is_protected;
ok $foo->meta->get_attribute('foo3')->is_private;

can_ok($foo,qw/public_rw public_ro set_public_a get_public_a private_ro private_rw set_private_a get_private_a protected_ro protected_rw set_protected_a get_protected_a/);

throws_ok {
	$foo->private_ro;
} qr/^private_ro\(\) is a private method of Foo/;

throws_ok{
	Foo->meta->add_attribute( bar => { modifier => 'Bar' } );
} qr/^Modifier for attribute \(bar\) must be 'Private', 'Protected' or 'Public'/;

done_testing;