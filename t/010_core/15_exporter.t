use strict;
use warnings;
use Test::More;
use Test::Exception;
use List::MoreUtils qw/all/;
use Shaft::Util ();
lives_ok {

	package Foo::Parent1;
	use Shaft;

	no Shaft;

	package Foo::Parent2;
	use Shaft;

	no Shaft;

	package Foo::Meta;
	use Shaft -extends => qw/Shaft::Meta::Class/;

	no Shaft;

	package Foo::Traits1;
	use Shaft::Role;

	sub trait1 { 1 }

	no Shaft::Role;

	package Foo::Traits2;
	use Shaft::Role;

	sub trait2 { 1 };

	no Shaft::Role;

	package Foo;
	use Shaft
		-extends   => [qw/Foo::Parent1 Foo::Parent2/],
		-metaclass => 'Foo::Meta',
		-traits    => ['Foo::Traits1', 'Foo::Traits2', { '-alias' => { 'trait2' => 'trait3' } }];

	use Shaft::Exporter;
	Shaft::Exporter->setup_import_methods(
		exports     => [ qw/foo1 foo2/, \&foo3, sub {1} ],
		with_meta   => [qw/foo4 foo5/],
		groups      => {
			default  => ['foo1'],
			standard => [qw/foo1 foo2/]
		}
	);

	sub foo1 {
		1;
	}

	sub foo2 {
		1;
	}

	sub foo3 {
		1;
	}

	sub foo4 {
		my $meta = shift;
		return $meta;
	}

	sub foo5($) {
		my $meta = shift;
		return $meta;
	}

	no Shaft;

	package Foo2;
	use Shaft::Exporter;

	Shaft::Exporter->setup_import_methods( exports => [qw/foo/], );

	sub import {1}

	sub unimport {1}

	sub foo {1}

	package Foo3;
	Foo2->import;

	package Bar;
	use Shaft::Exporter;
	Shaft::Exporter->setup_import_methods( exports_from => [qw/Foo/] );

	package Baz1;
	Foo->import;

	package Baz2;
	Foo->import(':standard');

	package Baz3;
	Foo->import('-standard');

	package Baz4;
	use Shaft;
	use namespace::clean -except => 'meta';
	Foo->import(':all');

	package Baz5;
	Foo->import(qw/foo1 foo3/);

	package Baz6;
	use Shaft;
	our $VERSION = '0.01';

	package Baz7;
	Foo->import( { into => 'Baz6' }, ':all' );

	package Baz8;
	Foo->import( { into_level => 1 }, ':all' );
	
	package Baz9;
	Foo->import({}, ':all' );

	package Baz10;
	Bar->import;

	package Baz11;
	Bar->import(':standard',qw/foo1 foo2 foo1/);

	package Baz12;
	use Shaft;
	use namespace::clean -except => 'meta';
	Bar->import(':all');

	package Baz13;
	Bar->import(qw/foo1 foo3/);
};

isa_ok( 'Foo', 'Foo::Parent1' );
isa_ok( 'Foo', 'Foo::Parent2' );
my $foo_meta = Foo->meta;
isa_ok $foo_meta, 'Foo::Meta';
ok $foo_meta->meta->is_anon_class;
ok $foo_meta->does('Foo::Traits1');
ok $foo_meta->does('Foo::Traits2');

can_ok(Foo->meta,qw/trait1 trait2 trait3/);

require Shaft::Meta::Class;

can_ok( 'Baz1', 'foo1' );
can_ok( 'Baz2', 'foo1', 'foo2' );
can_ok( 'Baz3', 'foo1', 'foo2' );

can_ok( 'Baz4', qw/foo1 foo2 foo3 foo4 foo5/ );
isa_ok( Baz4::foo4(), 'Shaft::Meta::Class' );
is( Baz4::foo4()->name, 'Baz4' );

can_ok( 'Baz5', 'foo1', 'foo3' );

can_ok( 'Baz6', qw/foo1 foo2 foo3 foo4 foo5/ );
isa_ok( Baz6::foo4(), 'Shaft::Meta::Class' );
is( Baz6::foo4()->name, 'Baz6' );

can_ok( 'main', qw/foo1 foo2 foo3 foo4 foo5/ );
can_ok( 'Baz9', qw/foo1 foo2 foo3 foo4 foo5/ );

ok !Foo3->can('foo');

can_ok( 'Baz10', 'foo1' );
can_ok( 'Baz11', 'foo1', 'foo2' );
can_ok( 'Baz12', qw/foo1 foo2 foo3 foo4 foo5/ );
can_ok( 'Baz13', 'foo1', 'foo3' );

isa_ok( Baz12::foo4(), 'Shaft::Meta::Class' );
is( Baz12::foo4()->name, 'Baz12' );


{
	package Baz13;
	use Shaft::Exporter;
	Shaft::Exporter->setup_import_methods(
		exports_from => 'Foo',
	);

	package Baz14;
	Shaft::Exporter->setup_import_methods(
		exports_from => 'Baz13',
	);

	package Baz15;
	Baz14->import(':all');
}
can_ok( 'Baz15', qw/foo1 foo2 foo3 foo4 foo5/ );

throws_ok {
	package Qux1;
	use Shaft::Exporter;
	Shaft::Exporter->setup_import_methods(
		exports => [qw/qux/],
	);

	sub init_meta {
		shift;
		my %args = @_;
		my $class = $args{for_class};
		my $meta = Shaft::Meta::Class->initialize($class);
		$meta->add_method( meta => sub{ 'Shaft::Meta::' } );
	}

	sub qux { 1 }

	package Qux2;
	Qux1->import( -traits => [qw/Foo::Traits/] );

} qr/^Can't determine metaclass type for trait application. Meta isa/;


dies_ok {
	package Hoge;
	Foo->import(':error');
};

throws_ok {

	package Hoge1;
	use Shaft::Exporter -setup => { exports => ['Hoge'] };

	sub Hoge {1}

	package Hoge2;
	Hoge1->import( -extends => 'Foo' );

}
qr/^Can't provide '-extends' when Hoge1 does not hove an init_meta\(\) method/;

throws_ok {

	package Hoge3;
	Hoge1->import( -traits => 'Foo' );
}
qr/^Can't provide '-traits' when Hoge1 does not hove an init_meta\(\) method/;

lives_ok {

	package Hogex1;
	use Shaft::Exporter -setup => [];

	package Hogex2;
	use Shaft::Exporter -setup => { exports => [qw/Hogex2_1 Hogex2_2/], };

	sub Hogex2_1 {1}
	sub Hogex2_2 {2}

	package Hogex3;
	Hogex2->import(':all');

	package Hogex4;
	Hogex2->import( ':all', -with_prefix => 'abc_', -with_suffix => '_def' );

	package Hogex5;
	use Shaft::Exporter -setup => { exports => {} };
};

can_ok( 'Hogex3', qw/Hogex2_1 Hogex2_2/ );
can_ok( 'Hogex4', qw/abc_Hogex2_1_def abc_Hogex2_2_def/ );

throws_ok {

	package Fuga;
	use Shaft::Exporter;
	Shaft::Exporter->setup_import_methods( exports_from => ['NOT::LOADED'] );
}
qr/^Package in exports_from \(NOT::LOADED\) does not seem to use Shaft::Exporter \(is it loaded\?\)/;

throws_ok {

	package Piyo;
	use Shaft::Exporter;
	Shaft::Exporter->setup_import_methods(
		exports_from => ['Shaft::Exception'] );
}
qr/^Package in exports_from \(Shaft::Exception\) does not seem to use Shaft::Exporter/;

throws_ok {

	package Piyo2;
	use Shaft::Exporter;
	Shaft::Exporter->setup_import_methods(
		exports => ['piyp2'],
		groups  => { default => {}, }
	);

	sub piyo2 {1}
}
qr/^The group value of 'default' must be ARRAY reference/;

throws_ok {

	package Piyo3;
	Foo->import(qw/bar baz/);
}
qr/^The Foo does not export 'bar'/;

lives_ok {

	package Piyo4;
	use Shaft::Exporter -setup => { export_from => 'Piyo3' };
};

lives_ok {

	package Piyo5;
	use Shaft -metaclass => '';
};
isa_ok( Piyo5->meta, 'Shaft::Meta::Class' );

lives_ok {

	package Piyo6;
	use Shaft::Exporter -setup => {
		exports     => {},
		with_caller => {},
		with_meta   => {},
		groups      => [],
	};
};

throws_ok {

	package Piyo7;
	use Shaft::Exporter;

	Shaft::Exporter->setup_import_methods( exports_from => [qw/Foo Foo/], );
}
qr/^Circular reference in exports_from parameter to Shaft::Exporter between/;

done_testing;
