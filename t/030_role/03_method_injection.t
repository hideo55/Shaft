use strict;
use warnings;
use Test::More;
use Test::Exception;

lives_ok {
	package Bar;
	use Shaft::Role;

	has 'attr1' => ( is => 'rw' );
	has 'attr2' => ( is => 'rw', pbp_style => 1 );
	has 'attr3' => ( is => 'ro' );

	sub bar{
		'ok';
	}
	
	sub baz{
		'ok';
	}

	package Foo;
	use Shaft;
	
	has 'attr3' => ( is => 'rw' );

	with 'Bar';

	sub baz{ 1 }
};

can_ok('Foo',qw/bar baz attr1 get_attr2 set_attr2 attr3/);

my $f = Foo->new;
is $f->bar, 'ok';
is $f->baz, 1;

ok $f->meta->get_attribute('attr3')->is_rw;

lives_ok{
	package Baz::Role1;
	use Shaft::Role;

	sub baz { 1 }

	sub baz1 { 1 }

	sub baz1_2 { 1 }

	package Baz::Role2;
	use Shaft::Role;

	__PACKAGE__->meta->add_method( baz => Baz::Role1->meta->get_method('baz') );

	sub baz2 { 1 }

	sub baz3 { 1 }

	package Baz;
	use Shaft;

	with 'Baz::Role1', 'Baz::Role2', { -alias => { baz2 => 'baz2_2', baz3 => 'baz3_2' }, -excludes => [qw/baz3/] };

	sub baz1_2 { 1 }
};
can_ok( 'Baz',qw(baz baz1 baz1_2 baz2 baz2_2 baz3_2) );
ok !Baz->can('baz3');

lives_ok {
	package Qux::Role;
	use Shaft::Role;

	sub qux { 1 }
	
	no Shaft::Role;

	package Qux;
	use Shaft;

	__PACKAGE__->meta->add_method( qux2 => Qux::Role->meta->get_method_body('qux') );

	with 'Qux::Role', { -alias => { qux => 'qux2' } };
};

throws_ok {
	package Quxx::Role;
	use Shaft::Role;

	sub quxx1 { 1 }

	package Quxx;
	use Shaft;

	sub quxx2 { 1 }

	with 'Quxx::Role', { -alias => { quxx1 => 'quxx2' } };
} qr/^Can't create a method alias if a local method of the same name exists/;

done_testing;