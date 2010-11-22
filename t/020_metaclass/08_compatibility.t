use strict;
use warnings;
use Test::More;
use Test::Exception;
use Shaft::Util qw(does_role);

{
	package FooTrait;
	use Shaft::Role;
	use namespace::clean -except => 'meta';
	
	has 'foo' => (is => 'rw' );
	
	sub foo_method {
		1;
	}
	
	package BarTrait;
	use Shaft::Role;
	use namespace::clean -except => 'meta';
	
	has 'bar' => (is => 'rw' );
	
	sub bar_method {
		1;
	}
	
	package BaseClass;
	use Shaft -traits => qw(FooTrait);
	
	package SubClass;
	use Shaft -traits => qw(BarTrait);
	
	extends 'BaseClass';
}

ok does_role(BaseClass->meta,'FooTrait'), 'BaseClass->meta->does("FooTrait")';
ok !does_role(BaseClass->meta,'BarTrait'), '!BaseClass->meta->does("BarTrait")';
ok does_role(SubClass->meta,'FooTrait'), 'SubClass->meta->does("FooTrait")';
ok does_role(SubClass->meta,'BarTrait'), 'SubClass->meta->does("BarTrait")';

throws_ok {
	package BaseClass2;
	use Shaft -traits => qw(FooTrait);
	
	package SubClass2;
	use Shaft -traits => [qw(BarTrait)];

	has 'baz1' => ( is => 'ro' );
	has 'baz2' => ( is => 'ro' );
	
	extends 'BaseClass2';
} qr/^Cannot attempt to reinitialize metaclass for SubClass2, it isn't pristine/;

lives_ok {
	package Foo::Meta1;
	use Shaft -extends => 'Shaft::Meta::Class';

	package Foo::Meta2;
	use Shaft -extends => 'Foo::Meta1';

	package BaseClass3;
	use Shaft -metaclass => 'Foo::Meta2';
	
	package SubClass3;
	use Shaft -metaclass => 'Foo::Meta1';

	extends 'BaseClass3';
};

throws_ok {
	package Trait1;
	use Shaft::Role;
	
	has 'foo' => ( is => 'rw' );

	package BaseMeta1;
	use Shaft -extends => 'Shaft::Meta::Class';

	has 'base' => ( is => 'rw' );

	sub base_meth { 1 }

	package BaseClass4;
	use Shaft -metaclass => 'BaseMeta1';
	use Shaft::Util::MetaRole;

	package SubClass4;
	use Shaft;

	Shaft::Util::MetaRole::apply_metaclass_roles(
		for_class => __PACKAGE__,
		metaclass_roles => [qw/Trait1/],
	);

	Shaft::Util::MetaRole::apply_metaclass_roles(
		for_class => ref(__PACKAGE__->meta),
		metaclass_roles => [qw/Trait1/],
	);

	extends 'BaseClass4';
} qr/^Shaft::Util::class_of\(.*?\) => \(.*?\) is not compatible with the Shaft::Util::class_of\(.*?\) => \(.*?\)/;

throws_ok {
	package Trait2;
	use Shaft::Role;

	package BaseMeta2;
	use Shaft -extends => 'Shaft::Meta::Class';
	
	package SubMeta1;
	use Shaft -extends => 'Shaft::Meta::Class';

	has 'sub_attr' => ( is => 'rw' );

	package BaseClass5;
	use Shaft -metaclass => 'BaseMeta1';
	use Shaft::Util::MetaRole;

	package SubClass5;
	use Shaft -metaclass => 'SubMeta1';

	Shaft::Util::MetaRole::apply_metaclass_roles(
		for_class => __PACKAGE__,
		metaclass_roles => [qw/Trait2/],
	);

	Shaft::Util::MetaRole::apply_metaclass_roles(
		for_class => ref(__PACKAGE__->meta),
		metaclass_roles => [qw/Trait2/],
	);

	__PACKAGE__->meta->superclasses('BaseClass5');
} qr/^Shaft::Util::class_of\(.*?\) => \(.*?\) is not compatible with the Shaft::Util::class_of\(.*?\) => \(.*?\)/;

lives_ok {
	package Trait3;
	use Shaft::Role;

	has 'attr3' => ( is => 'rw' );

	package BaseClass6;
	use Shaft -traits => 'Trait2';

	package SubClass6;
	use Shaft;

	Shaft::Util::MetaRole::apply_metaclass_roles(
		for_class => __PACKAGE__,
		metaclass_roles => [qw/Trait3/],
		attribute_metaclass_roles => [qw/Trait3/],
	);

	extends 'BaseClass6';
};


{
	package BaseClass7;
	use Shaft;

	package DummyMeta;
	use Shaft;
}

Shaft::Util::store_metaclass_by_name( BaseClass7 => DummyMeta->new() );

throws_ok {
	package SubClass7;
	use Shaft;
	extends 'BaseClass7';
} qr/^The super metaclass '.*?' isn't inherit 'Shaft::Meta::Class'/;


{
	package BaseClass8;
	use Shaft;

	Shaft::Util::MetaRole::apply_metaclass_roles(
		for_class => __PACKAGE__,
		metaclass_roles => [qw/Trait2/],
		constructor_class_roles => [qw/Trait2/],
		attribute_metaclass_roles => [qw/Trait2/],
	);

	package SubClass8;
	use Shaft;

	Shaft::Util::MetaRole::apply_metaclass_roles(
		for_class => __PACKAGE__,
		constructor_class_roles => [qw/Trait3/],
		attribute_metaclass_roles => [qw/Trait3/],
	);

	extends 'BaseClass8';
}

lives_ok{
	package SharedMeta;
	use Shaft -extends => 'Shaft::Meta::Class';
	
	has 'shared_attr' => ( is => 'rw' );

	package BaseMeta4;
	use Shaft -extends => 'SharedMeta';

	package SubMeta4;
	use Shaft -extends => 'SharedMeta';
	package BaseClass9;
	use Shaft -metaclass => 'BaseMeta4';

	package SubClass9;
	use Shaft -metaclass => 'SubMeta4';
	extends 'BaseClass9';
};

done_testing;