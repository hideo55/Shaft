use strict;
use warnings;
use Test::More;
use Test::Exception;

lives_ok{	
	package Foo;
	use Shaft ();
	
	sub test1 {
		Shaft::init_meta('Foo');
	}
	
	sub test2{
		Foo->meta->remove_method('meta');
		Shaft->init_meta( for_class => 'Foo' );
	}
	
	package Bar::Meta;
	use Shaft;
	extends 'Shaft::Meta::Class';
	
	package Bar;
	use Shaft ();
	our @ISA = qw(Foo);
	
	sub test3 {
		Shaft->init_meta(
			for_class => 'Bar',
			base_class => 'Foo',
		);
	}
	
	sub test4 {
		Bar->meta->remove_method('meta');
		Shaft::Util::remove_metaclass_by_name('Bar');
		Shaft->init_meta( for_class => 'Bar', metaclass => 'Bar::Meta' );
	}
};

my $foo_meta = Foo->test1;
isa_ok($foo_meta, 'Shaft::Meta::Class');
ok( $foo_meta->name eq 'Foo');
can_ok('Foo','meta');
can_ok(Foo->new,'meta');
throws_ok{ 
	Foo->can('meta')->();
} qr/^You must pass a package name and it cannot be blessed/;

$foo_meta = Foo->test2;
isa_ok($foo_meta, 'Shaft::Meta::Class');
ok( $foo_meta->name eq 'Foo');

Bar->test3;
my $bar = Bar->new;
isa_ok($bar,'Foo');

Bar->test4;
isa_ok(Bar->meta ,'Bar::Meta');

lives_ok {
	package Foo2;

	sub foo { 1 }
	
	package Foo3;
	use Shaft -extends => 'Foo2';
};

lives_ok {
	Shaft->init_meta( for_class => 'Foo3' );
};

lives_ok {
	package Foo::Meta;
	use Shaft -extends => 'Shaft::Meta::Class';

	package Foo4;
	use Shaft -metaclass => 'Foo::Meta';

	package Foo5;
	use Shaft -extends => 'Foo4';
};

lives_ok {
	Shaft->init_meta( for_class => 'Foo5' );
};

lives_ok{
	package Baz;
	use Shaft ();

	sub test1{
		Shaft->init_meta();
	}

	sub test2{
		no strict 'refs';
		*Baz::meta = sub { 'Foo' };
		Shaft->init_meta( for_class => 'Baz' );
	}
	
	sub test3 {
		no strict 'refs';
		no warnings 'redefine';
		*Baz::meta = sub { Foo->new };
		Shaft->init_meta( for_class => 'Baz' );
	}

	sub test4 {
		Shaft->init_meta( for_class => 'Baz', metaclass => 'Foo' );
	}
};

throws_ok {
	Baz::test1();
} qr/^Cannot call init_meta without specifying a for_class/;

throws_ok {
	Baz::test2()
} qr /^Baz already has a &meta function, but it does not return a Shaft::Meta::Class/;

throws_ok {
	Baz::test3();
} qr/^Baz already has a &meta function, but it does not return a Shaft::Meta::Class/;

throws_ok {
	Baz::test4();
} qr/The Metaclass Foo must be a subclass of Shaft::Meta::Class/;

lives_ok {
	package Shaft::Meta::Role::SubClass;
	use Shaft -extends => 'Shaft::Meta::Role';
	
	package Qux;
	use Shaft::Role -metaclass => 'Shaft::Meta::Role::SubClass';
};

my $role_meta = Qux->meta;
isa_ok $role_meta, 'Shaft::Meta::Role';
isa_ok $role_meta, 'Shaft::Meta::Role::SubClass';

my $blessed = bless {}, 'Qux';
isa_ok $blessed->meta, 'Shaft::Meta::Role';

throws_ok {
	Qux->can('meta')->();
} qr/^You must pass a package name and it cannot be blessed/;

$role_meta->add_method( meta => sub{ $foo_meta } );
throws_ok {
	Shaft::Role->init_meta( for_class => 'Qux' );
} qr/^You already have a &meta function, but it does not return a Shaft::Meta::Role/;

$role_meta->add_method( meta => sub{ 'Foo' } );
throws_ok {
	Shaft::Role->init_meta( for_class => 'Qux' );
} qr/^You already have a &meta function, but it does not return a Shaft::Meta::Role/;

lives_ok {
	package Hoge1;
	our $VERSION;
	
	package Hoge2::Meta;
	use Shaft -extends => 'Shaft::Meta::Class';
	
	package Hoge2;
	use Shaft -metaclass => 'Hoge2::Meta';
	
	package Hoge3::Meta;
	use Shaft -extends => 'Shaft::Meta::Class';
	
	package Hoge3;
	our @ISA;
	BEGIN{
		@ISA = qw(Hoge1 Hoge2);
	}
	use Shaft -metaclass => 'Hoge3::Meta';	
};

{
	package Fuga;

	package Fuga::Role;
}

throws_ok{
	Shaft::Meta::Class->reinitialize('Fuga');
} qr/^The 'Fuga' is not initialized yet/;

throws_ok {
	Shaft::Meta::Role->reinitialize('Fuga::Role');
} qr/^The 'Fuga::Role' is not initialized yet/;

done_testing;