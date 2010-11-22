use strict;
use warnings;
use Test::More;
use Test::Exception;
use Shaft::Util::MetaRole;
use Shaft::Util qw(does);

{

	package Foo;
	use Shaft;

	no Shaft;

	package Bar;
	use Shaft -extends => 'Foo';

	no Shaft;

	package Foo::Role;
	use Shaft::Role;
	no Shaft::Role;

}

Shaft::Util::MetaRole::apply_base_class_roles(
	for_class => 'Bar',
	roles     => [qw/Foo::Role/],
);

isa_ok( 'Bar', 'Foo' );
ok( Bar->does('Foo::Role') );
my $super = ( Bar->meta->superclasses )[0];
ok $super =~ /^Shaft::Meta::Class::__ANON__/;
ok $super->meta->is_anon_class;
isa_ok $super, 'Foo';
ok $super->meta->does_role('Foo::Role');

Shaft::Util::MetaRole::apply_base_class_roles(
	for_class => 'Bar',
	roles     => [qw/Foo::Role/],
);
my $new_super = ( Bar->meta->superclasses )[0];

is $super,$new_super;

lives_ok {

	package Baz::Role;
	use Shaft::Role;

	package Baz;
	use Shaft;

	package Qux;
	use Shaft;
	extends 'Baz';
	use Shaft::Util::MetaRole;

	Shaft::Util::MetaRole::apply_metaclass_roles(
		for_class                      => 'Baz',
		metaclass_roles                => [qw/Baz::Role/],
		attribute_metaclass_roles      => [qw/Baz::Role/],
		method_metaclass_roles         => [qw/Baz::Role/],
		wrapped_method_metaclass_roles => [qw/Baz::Role/],
		constructor_class_roles        => [qw/Baz::Role/],
		destructor_class_roles         => [qw/Baz::Role/],
	);
	Shaft::Util::remove_metaclass_by_name('Qux');
	Shaft->init_meta( for_class => 'Qux' );
};

ok( Baz->meta->meta->is_anon_class );
ok( Qux->meta->meta->is_anon_class );
ok( does( Baz->meta, 'Baz::Role' ) );
ok( does( Qux->meta, 'Baz::Role' ) );

ok( does( Baz->meta->constructor_class,        'Baz::Role' ) );
ok( does( Baz->meta->destructor_class,         'Baz::Role' ) );
ok( does( Baz->meta->attribute_metaclass,      'Baz::Role' ) );
ok( does( Baz->meta->method_metaclass,         'Baz::Role' ) );
ok( does( Baz->meta->wrapped_method_metaclass, 'Baz::Role' ) );

my $qux_meta = Qux->meta;

my $qux_meta2 = Shaft::Util::MetaRole::apply_metaclass_roles(
	for_class => 'Qux',
);

ok $qux_meta == $qux_meta2;

throws_ok {

	package Quxx;
	use Shaft::Role;
	require Shaft;
	Shaft->import;
}
qr/Quxx already has a metaclass, but it does not inherit/;

{
	package Hoge;
	use Shaft;
};

Shaft::Util::MetaRole::apply_metaclass_roles(
	for_class => 'Hoge',
	metaclass_roles => [{}]
);
is ref(Hoge->meta), 'Shaft::Meta::Class';

done_testing;
