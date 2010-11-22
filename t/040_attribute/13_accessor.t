use strict;
use warnings;
use Test::More;
use Test::Exception;

{

	package Foo;
	use Shaft;

	has foo1 => ( is => 'rw' );
	has foo2 => ( is => 'ro' );
	has foo3 => ( is => 'rw', reader => 'get_foo3', writer => 'set_foo3' );
	has foo4 => ( is => 'ro', reader => 'get_foo4', writer => 'set_foo4' );
	has foo5  => ( is => 'rw', pbp_style => 1 );
	has foo6  => ( is => 'ro', pbp_style => 1 );
	has _foo7 => ( is => 'rw', pbp_style => 1 );
	has _foo8 => ( is => 'ro', pbp_style => 1 );
}

my $foo = Foo->new;
can_ok(
	$foo,       'foo1',      'foo2',      'get_foo3',
	'set_foo3', 'get_foo4',  'get_foo5',  'set_foo5',
	'get_foo6', '_get_foo7', '_set_foo7', '_get_foo8'
);

ok !$foo->can('set_foo4');
ok !$foo->can('set_foo6');
ok !$foo->can('_set_foo8');

ok $foo->meta->get_attribute('foo1')->has_reader;
ok $foo->meta->get_attribute('foo1')->has_writer;
is $foo->meta->get_attribute('foo1')->reader, 'foo1';
is $foo->meta->get_attribute('foo1')->writer, 'foo1';

ok $foo->meta->get_attribute('foo2')->has_reader;
ok !$foo->meta->get_attribute('foo2')->has_writer;
is $foo->meta->get_attribute('foo2')->reader, 'foo2';
is $foo->meta->get_attribute('foo2')->writer, undef;

ok $foo->meta->get_attribute('foo3')->has_reader;
ok $foo->meta->get_attribute('foo3')->has_writer;
is $foo->meta->get_attribute('foo3')->reader, 'get_foo3';
is $foo->meta->get_attribute('foo3')->writer, 'set_foo3';

ok $foo->meta->get_attribute('foo4')->has_reader;
ok !$foo->meta->get_attribute('foo4')->has_writer;
is $foo->meta->get_attribute('foo4')->reader, 'get_foo4';
is $foo->meta->get_attribute('foo4')->writer, undef;

ok $foo->meta->get_attribute('foo5')->has_reader;
ok $foo->meta->get_attribute('foo5')->has_writer;
is $foo->meta->get_attribute('foo5')->reader, 'get_foo5';
is $foo->meta->get_attribute('foo5')->writer, 'set_foo5';

ok $foo->meta->get_attribute('foo6')->has_reader;
ok !$foo->meta->get_attribute('foo6')->has_writer;
is $foo->meta->get_attribute('foo6')->reader, 'get_foo6';
is $foo->meta->get_attribute('foo6')->writer, undef;

ok $foo->meta->get_attribute('_foo7')->has_reader;
ok $foo->meta->get_attribute('_foo7')->has_writer;
is $foo->meta->get_attribute('_foo7')->reader, '_get_foo7';
is $foo->meta->get_attribute('_foo7')->writer, '_set_foo7';

ok $foo->meta->get_attribute('_foo8')->has_reader;
ok !$foo->meta->get_attribute('_foo8')->has_writer;
is $foo->meta->get_attribute('_foo8')->reader, '_get_foo8';
is $foo->meta->get_attribute('_foo8')->writer, undef;

throws_ok {

	package Bar;
	use Shaft;

	has '1a' => ( is => 'rw' );
}
qr/Can't use '1a' for attribute  name because it's contain invalid character/;

throws_ok {

	package Baz;
	use Shaft;

	has 'baz' => ( is => 'rw', reader => '1a' );
}
qr/Can't use '1a' for reader method name because it's contain invalid character/;

throws_ok {

	package Qux;
	use Shaft;

	has 'qux' => ( is => 'rw', writer => '1a' );
}
qr/Can't use '1a' for writer method name because it's contain invalid character/;

lives_ok{
	package Quxx;
	use Shaft;

	Private 'quxx1' => ( is => 'rw', pbp_style => 1 );
	Protected 'quxx2' => ( is => 'rw', pbp_style => 1 );
	Public 'quxx3' => ( is => 'rw', pbp_style => 1 );

	Private 'quxx4' => ( is => 'rw'  );
	Protected 'quxx5' => ( is => 'rw' );
	Public 'quxx6' => ( is => 'rw' );

};

done_testing;
