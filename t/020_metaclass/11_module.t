use strict;
use warnings;
use Test::More;
use Test::Exception;
{
	package Foo;
	use Shaft;

	our $VERSION = '0.01';
	$VERSION = eval $VERSION;

	our $AUTHORITY = 'John';

	package Bar;
	use Shaft;

}

is( Foo->meta->version,'0.01');
is(Foo->meta->authority,'John');
is(Foo->meta->identifier,'Foo-0.01-John');

ok !defined(Bar->meta->version);
ok !defined(Bar->meta->authority);
is(Bar->meta->identifier,'Bar');

throws_ok {
	Bar->meta->initialize();
} qr/^You must pass a package name and it cannot be blessed/;

throws_ok {
	Bar->meta->initialize(Bar->meta);
} qr/^You must pass a package name and it cannot be blessed/;

throws_ok {
	Bar->meta->reinitialize();
} qr/^You must pass a package name and it cannot be blessed/;

throws_ok {
	Bar->meta->reinitialize(Bar->meta);
} qr/^You must pass a package name and it cannot be blessed/;

{
	package Baz;
	use Shaft;
	use Scalar::Util qw(blessed);

	use constant foo => 'foo';

	sub bar { 1 }
}
my $meta = Baz->meta;

ok $meta->has_method('foo');
ok $meta->has_method('bar');
ok !$meta->has_method('baz');
ok !$meta->has_method('blessed');

ok $meta->get_method('foo'),'constant subroutine';
ok $meta->get_method('bar'),'normal subroutine';
my $code = sub{ 1 };
ok !$meta->_code_is_mine($code),'Anonymous subroutine';
ok !$meta->_code_is_mine(Baz->can('blessed')), q{other package's subroutine};
ok !$meta->_code_is_mine(constant->can('import'));
$code = Baz->can('bar');
$meta->remove_method('bar');
ok(!Baz->can('bar'));

done_testing;