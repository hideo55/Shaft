use strict;
use warnings;
use Test::More;
use Test::Exception;

{

	package Foo;
	use Shaft::Role;

	sub hoge : FooAttr {
		1;
	}

	sub fuga {
		1;
	}

	before fuga => sub {
		1;
	};

	after fuga => sub {
		1;
	};

	around fuga => sub {
		1;
	};

	override bar => sub {
		super();
	};
}

isa_ok( Foo->meta, 'Shaft::Meta::Role' );

#Method
Foo->meta->add_method( foo => sub {'foo'} );
can_ok('Foo', 'foo');
is( Foo->foo, 'foo' );
ok( Foo->meta->has_method('foo') );
ok( Foo->meta->get_method_body('foo') );
Foo->meta->remove_method('foo');
ok( !Foo->can('foo') );

#Attribute
Foo->meta->add_attribute( bar => { is => 'rw', isa => 'Int', default => 0 } );
ok( Foo->meta->has_attribute('bar') );
Foo->meta->remove_attribute('bar');
ok( ! Foo->meta->has_attribute('bar') );

#Method modifier
ok( Foo->meta->get_before_method_modifier('fuga') );
ok( Foo->meta->get_after_method_modifier('fuga') );
ok( Foo->meta->get_around_method_modifier('fuga') );
ok( Foo->meta->get_override_method_modifier('bar') );

#Method attribute
my @method_attributes = Foo->meta->get_method_attributes_by_method('hoge');
ok (scalar @method_attributes == 1);
ok (ref $method_attributes[0] eq 'Shaft::MethodAttributes::Spec' );
is $method_attributes[0]->[0],'Foo';
is $method_attributes[0]->[2], 'FooAttr';
@method_attributes = Foo->meta->get_method_attributes_by_methodref(Foo->can('hoge'));
ok (scalar @method_attributes == 1);
ok (ref $method_attributes[0] eq 'Shaft::MethodAttributes::Spec' );
is $method_attributes[0]->[0],'Foo';
is $method_attributes[0]->[2], 'FooAttr';

{
	package Foo::Meta::Method;
	use Shaft -extends => 'Shaft::Meta::Method';
}

Foo->meta->reinitialize( 'Foo', method_metaclass => 'Foo::Meta::Method' );
is( Foo->meta->method_metaclass, 'Foo::Meta::Method' );

#Anon Role

my $anon = Foo->meta->create_anon_role(
	methods => {
		meth1 => sub {1},
		meth2 => sub {2}
	},
	attributes => {
		attr1 => { is => 'ro' },
		attr2 => { is => 'rw' },
	},
	superclasses => [],
);

isa_ok $anon, 'Shaft::Meta::Role';
ok $anon->is_anon_role;
ok $anon->name =~ /^Shaft::Meta::Role::__ANON__::/;
ok $anon->has_method('meth1');
ok $anon->has_method('meth2');
ok $anon->has_attribute('attr1');
ok $anon->has_attribute('attr2');
isa_ok $anon->meta,'Shaft::Meta::Class';

throws_ok{
	package Bar;	
	use Shaft::Role;
	
	Shaft::Role->init_meta();
} qr/^Can't call init_meta without specifying a for_class/;


{
	package Baz::Class;
	use Shaft;
}

throws_ok{ 
	package Baz;
	use Shaft::Role;
	
	__PACKAGE__->meta->add_method( meta => sub{ Baz::Class->new } );

	Shaft::Role->init_meta( for_class => 'Baz' );

} qr/^You already have a &meta function, but it does not return a Shaft::Meta::Role/;

lives_ok{
	package Qux;
	use Shaft::Role;

	Shaft::Role->init_meta( for_class => 'Qux' );
};

{
	package Bar;
	use Shaft::Role;
	with 'Qux';

	package Quxx;
	use Shaft::Role;

	with 'Bar','Qux';
}

ok( Bar->meta->does_role('Bar') );
ok( Bar->meta->does_role('Qux') );
ok( !Bar->meta->does_role('Baz') );
ok( Quxx->meta->does_role('Quxx') );

throws_ok {
	Bar->meta->does_role();
} qr/^You must supply a role name to look for/;

my @roles = map{ $_->name } Quxx->meta->calculate_all_roles;
is scalar(@roles),4;

done_testing;