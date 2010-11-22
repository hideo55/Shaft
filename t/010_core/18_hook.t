use strict;
use warnings;
use Test::More;
use Test::Exception;
{
	package Foo;
	use Shaft;

	sub call{
		my ($self, $hp, $reverse) = @_;
		return $self->call_hook($hp,$reverse);
	}

	no Shaft;
	__PACKAGE__->meta->make_immutable;
}

my $foo = Foo->new;
ok !$foo->has_hook('foo');
$foo->add_hook( 'foo' => sub{ 1 } );
ok $foo->has_hook('foo');
my @res = $foo->call('foo');
is_deeply(\@res,[1]);
@res = $foo->call('foo',1);
is_deeply(\@res,[1]);
@res = $foo->call('bar');
is_deeply(\@res,[]);
$foo->add_hook( 'foo' => sub{ 2 } );

$foo->add_hook( 'foo' => sub{ 3 } );
@res = $foo->call('foo');
is_deeply(\@res,[1,2,3]);
@res = $foo->call('foo',1);
is_deeply(\@res,[3,2,1]);

my $foo2 = $foo->clone;
ok $foo2->has_hook('foo');
@res = $foo2->call('foo');
is_deeply(\@res,[1,2,3]);
@res = $foo2->call('foo',1);
is_deeply(\@res,[3,2,1]);


$foo->clear_hook('foo');
is $foo->call('foo'), undef;

@res = $foo2->call('foo');
is_deeply(\@res,[1,2,3]);
@res = $foo2->call('foo',1);
is_deeply(\@res,[3,2,1]);

ok !$foo->has_hook('bar');
is $foo->call('bar'), undef;
ok !$foo->has_hook;
is $foo->call, undef;

throws_ok {
	$foo->call_hook('foo');
} qr/^call_hook\(\) is a private method of/;

throws_ok {
	$foo->add_hook( 'baz' => {} );
} qr/^You must supply CODE reference as hook/;

done_testing;