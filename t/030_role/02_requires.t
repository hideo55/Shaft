use strict;
use warnings;
use Test::More;
use Test::Exception;

lives_ok {

	package Foo::Role;
	use Shaft::Role;

	requires qw(foo1 foo2 foo3);

	sub foo { 1 }

	package Foo;
	use Shaft;

	with 'Foo::Role', { -alias => { 'foo' => 'foo3' } };

	sub foo1 {
		'ok';
	}

	sub foo2 {
		'ok';
	}

};

my $f = Foo->new;
can_ok( $f, qw/foo1 foo2 foo3/ );

my $meta = Foo::Role->meta;
is_deeply(scalar($meta->get_required_method_list),[qw/foo1 foo2 foo3/]);
my @required = $meta->get_required_method_list;
is_deeply(\@required,[qw/foo1 foo2 foo3/]);

lives_ok {
	package Bar::Role1;
	use Shaft::Role;
	requires qw(bar1 bar2);
	
	package Bar::Role2;
	use Shaft::Role;

	sub bar { 1 }

	package Bar::Role3;
	use Shaft::Role;

	sub bar1 { 1 }

	package Bar;
	use Shaft;
	with 'Bar::Role1', 'Bar::Role2', { -alias => { bar => 'bar2' } },'Bar::Role3';
};
my ($role) = Bar->meta->roles;
can_ok('Bar', qw/bar1 bar2/);

throws_ok {

	package Baz::Role;
	use Shaft::Role;

	requires qw(baz1 baz2 baz3);

	package Baz;
	use Shaft;
	with 'Baz::Role';

	sub baz1 {1}

	sub baz3 { }

}
qr/^The role 'Baz::Role' requires the methods 'baz2' to be implemented by 'Baz'/;

throws_ok {
	package Qux::Role1;
	use Shaft::Role;

	requires qw(qux1 qux2);

	no Shaft::Role;
	package Qux::Role2;
	use Shaft::Role;
	
	requires qw(qux3 qux4);
	
	sub qux1 { 1 }

	sub qux2 { 1 }

	no Shaft::Role;

	package Qux;
	use Shaft;

	with qw(Qux::Role1 Qux::Role2);

	sub qux3 { 1 }

} qr/^The role '.*?' requires the methods 'qux4' to be implemented by 'Qux'/;

done_testing;
