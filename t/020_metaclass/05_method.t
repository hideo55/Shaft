use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;
	
	sub foo1 {
		1;
	}
	
	sub foo2 {
		'SUPER';
	}
	
	sub foo3 {
		inner();
	}
	
	package Foo::Role;
	use Shaft::Role;
	
	sub foo4 {
		'role';
	}
	
	package Bar;
	use Shaft;
	
	sub handler {
		'HANDLER';
	}
	
	
	package Baz;
	use Shaft -extends => 'Foo';
	
	with 'Foo::Role';
	
	Private bar => ( is => 'ro', isa => 'Bar', builder => '_build_bar', handles => [qw/handler/] );
	
	sub _build_bar {
		Bar->new;
	}
	
	around foo1 => sub{
		my $next = shift;
		$next->();
	};
	
	override foo2 => sub{
		super();
	};
	
	augment foo3 => sub {
		'INNER';
	};
	
	package Hoge;
	
}

my @methods;
lives_ok{ @methods = Baz->meta->get_all_method_names };

#Normal method
Foo->meta->add_method( test => sub{ 1 } );
ok( Foo->meta->has_method('test') );
ok( Foo->meta->get_method_body('test') );
my $method = Foo->meta->get_method('test');
isa_ok( $method, 'Shaft::Meta::Method' ); 
is $method->name,'test';
is $method->package_name,'Foo';
is $method->original_method, undef;
is $method->original_fully_qualified_name,'Foo::test';
isa_ok( $method->associated_metaclass, 'Shaft::Meta::Class' );
is $method->associated_metaclass->name, 'Foo';
ok( $method->body == Foo->can('test') );
ok(grep{/^test$/} Foo->meta->get_method_list,'Check added_method');
my $clone = $method->clone( package_name => 'Bar', name => 'test2' );
is $clone->name,'test2';
isa_ok($clone,'Shaft::Meta::Method');
ok $clone->original_method == $method;
is $method->original_fully_qualified_name, $clone->original_fully_qualified_name;
is $method->original_name, 'test';
is $clone->fully_qualified_name,'Bar::test2';
ok( $method->body == $clone->body );
is $method->(), 1;
is $method->execute(), 1;
my $method2 = Foo->meta->remove_method('test');
is $method, $method2;
ok !Foo->meta->has_method('test');
Foo->meta->add_method( test => $method2 );
ok( Foo->meta->has_method('test') );

throws_ok { Shaft::Meta::Method->new() } qr/^You must supply a CODE reference to bless, not/;
throws_ok { Shaft::Meta::Method->new({}) } qr/^You must supply a CODE reference to bless, not/;
throws_ok { Shaft::Meta::Method->new(sub{}, package_name => 'Foo' ) } qr/^You must supply the package_name and name parameters/;
throws_ok { Shaft::Meta::Method->new(sub{}) } qr/^You must supply the package_name and name parameters/;

throws_ok {
	Foo->meta->add_method( '' => sub{ 1 } );
} qr/^Can't use '' for method name because it's contain invalid character/;

throws_ok {
	Foo->meta->add_method( '1abc' => sub{ 1 } );
} qr/^Can't use '1abc' for method name because it's contain invalid character/;

throws_ok {
	Foo->meta->find_next_method_by_name(undef);
} qr/^You must define a method name to find/;

throws_ok {
	Foo->meta->find_next_method_by_name('');
} qr/^You must define a method name to find/;

throws_ok {
	Foo->meta->find_all_methods_by_name(undef);
} qr/^You must define a method name to find/;

throws_ok {
	Foo->meta->find_all_methods_by_name('');
} qr/^You must define a method name to find/;

#Wrapped method
my $wrapped = Baz->meta->get_method('foo1');
isa_ok($wrapped,'Shaft::Meta::Method::Wrapped');
is $wrapped->fully_qualified_name, 'Baz::foo1';
is $wrapped->original_name, 'foo1';
is $wrapped->original_fully_qualified_name, 'Foo::foo1';
isa_ok( $wrapped->associated_metaclass, 'Shaft::Meta::Class' );
is $wrapped->associated_metaclass->name, 'Baz';
ok( $wrapped->body == Baz->can('foo1') );
ok(grep{/^foo1$/} Baz->meta->get_method_list,'Check added_method');
my $clone_w = $wrapped->clone( package_name => 'Bar', name => 'foo11' );
is $wrapped->original_fully_qualified_name, $clone_w->original_fully_qualified_name;
is $clone_w->fully_qualified_name,'Bar::foo11';
ok( $wrapped->body == $clone_w->body );

lives_ok{ Shaft::Meta::Method::Wrapped->new($method, package_name => 'Foo', name => 'foo2' ) };

my $method3 = bless do{my $anon; \$anon},'Shaft::Meta::Method';
$$method3 = $method3 + 0;

throws_ok { 
	Shaft::Meta::Method::Wrapped->new($method3) 
} qr/You must supply the package_name and name parameters/;
throws_ok { Shaft::Meta::Method::Wrapped->new(sub{1}) } qr/Can only wrap blessed CODE/;
throws_ok { Shaft::Meta::Method::Wrapped->new(bless sub{1}, 'Hoge') } qr/Can only wrap blessed CODE/;

#Overridden method
my $overridden = Baz->meta->get_method('foo2');
isa_ok($overridden,'Shaft::Meta::Method::Generated');
isa_ok($overridden,'Shaft::Meta::Method::Overridden');
is $overridden->fully_qualified_name, 'Baz::foo2';
is $overridden->original_fully_qualified_name, 'Baz::foo2';
isa_ok( $overridden->associated_metaclass, 'Shaft::Meta::Class' );
is $overridden->associated_metaclass->name, 'Baz';
ok( $overridden->body == Baz->can('foo2') );
ok(grep{/^foo2$/} Baz->meta->get_method_list,'Check added_method');
my $clone_o = $overridden->clone( package_name => 'Bar', name => 'foo22' );
is $overridden->original_fully_qualified_name, $clone_o->original_fully_qualified_name;
is $clone_o->fully_qualified_name,'Bar::foo22';
ok( $overridden->body == $clone_o->body );
lives_ok{
	Shaft::Meta::Method::Overridden->new(
		class => Baz->meta,
		package => 'Baz',
		name => 'foo1',
		method => sub { super() },
	);
};
dies_ok{
	Shaft::Meta::Method::Overridden->new(
		name => 'foo1',
		method => sub { super() },
	);
}

#Augmented method
my $augmentd = Baz->meta->get_method('foo3');
isa_ok($augmentd,'Shaft::Meta::Method::Generated');
isa_ok($augmentd,'Shaft::Meta::Method::Augmented');
is $augmentd->fully_qualified_name, 'Baz::foo3';
is $augmentd->original_fully_qualified_name, 'Baz::foo3';
isa_ok( $augmentd->associated_metaclass, 'Shaft::Meta::Class' );
is $augmentd->associated_metaclass->name, 'Baz';
ok( $augmentd->body == Baz->can('foo3') );
ok(grep{/^foo3$/} Baz->meta->get_method_list,'Check added_method');
my $clone_au = $augmentd->clone( package_name => 'Bar', name => 'foo33' );
is $augmentd->original_fully_qualified_name, $clone_au ->original_fully_qualified_name;
is $clone_au ->fully_qualified_name,'Bar::foo33';
ok( $augmentd->body == $clone_au->body );

is( Baz->meta->_find_next_method_by_name_which_is_not_overridden('foo5'), undef);

#Accessor method
my $accessor = Baz->meta->get_method('bar');
isa_ok($accessor,'Shaft::Meta::Method::Generated');
isa_ok($accessor,'Shaft::Meta::Method::Accessor');
is $accessor->fully_qualified_name, 'Baz::bar';
is $accessor->original_fully_qualified_name, 'Baz::bar';
isa_ok( $accessor->associated_metaclass, 'Shaft::Meta::Class' );
is $accessor->associated_metaclass->name, 'Baz';
isa_ok( $accessor->associated_attribute,'Shaft::Meta::Attribute');
is $accessor->associated_attribute->name, 'bar';
ok( $accessor->body == Baz->can('bar') );
ok(grep{/^foo3$/} Baz->meta->get_method_list,'Check added_method');
my $clone_ac = $accessor->clone( package_name => 'Bar', name => 'bar1' );
is $accessor->original_fully_qualified_name, $clone_ac ->original_fully_qualified_name;
is $clone_ac ->fully_qualified_name,'Bar::bar1';
ok( $accessor->body == $clone_ac->body );

throws_ok {Shaft::Meta::Method::Accessor->new(sub{1}) } qr/You must supply an attribute to construct with/;
throws_ok {Shaft::Meta::Method::Accessor->new(sub{1}, attribute => 'foo' ) } qr/You must supply an attribute which is a 'Shaft::Meta::Attribute'/;
throws_ok {Shaft::Meta::Method::Accessor->new(sub{1}, attribute => Foo->new )} qr/You must supply an attribute which is a 'Shaft::Meta::Attribute'/;


#Delegation method
my $delegation = Baz->meta->get_method('handler');
isa_ok($delegation,'Shaft::Meta::Method::Generated');
isa_ok($delegation,'Shaft::Meta::Method::Delegation');
is $delegation->fully_qualified_name, 'Baz::handler';
is $delegation->original_fully_qualified_name, 'Baz::handler';
isa_ok( $delegation->associated_metaclass, 'Shaft::Meta::Class' );
is $delegation->associated_metaclass->name, 'Baz';
isa_ok( $delegation->associated_attribute,'Shaft::Meta::Attribute');
is $delegation->associated_attribute->name, 'bar';
ok( $delegation->body == Baz->can('handler') );
ok(grep{/^handler$/} Baz->meta->get_method_list,'Check added_method');
my $clone_dl = $delegation->clone( package_name => 'Bar', name => 'handler1' );
is $delegation->original_fully_qualified_name, $clone_dl ->original_fully_qualified_name;
is $clone_dl ->fully_qualified_name,'Bar::handler1';
ok( $delegation->body == $clone_dl->body );
my $baz = Baz->new;
is $baz->handler,'HANDLER';

throws_ok {Shaft::Meta::Method::Delegation->new() } qr/You must supply an attribute to construct with/;
throws_ok {Shaft::Meta::Method::Delegation->new( attribute => 'foo' ) } qr/You must supply an attribute which is a 'Shaft::Meta::Attribute'/;
throws_ok {Shaft::Meta::Method::Delegation->new( attribute => Foo->new )} qr/You must supply an attribute which is a 'Shaft::Meta::Attribute'/;
my $attr = Baz->meta->get_attribute('bar');
throws_ok {Shaft::Meta::Method::Delegation->new( attribute => $attr,)} qr/You must supply a delegate_to_method which is a method name or a CODE reference/;
throws_ok {
	Shaft::Meta::Method::Delegation->new( attribute => $attr, delegate_to_method => {} )
} qr/^You must supply a delegate_to_method which is a method name or a CODE reference/;
throws_ok {
	Shaft::Meta::Method::Delegation->new( attribute => $attr, delegate_to_method => sub{}, curried_argments => 'foo' );
}qr/^You must supply a curried_arguments which is an ARRAY reference/;
throws_ok{
	Shaft::Meta::Method::Delegation->new( attribute => $attr, delegate_to_method => sub{}, );
} qr/^You must supply the package_name and name parameters/;
throws_ok{
	Shaft::Meta::Method::Delegation->new( attribute => $attr, delegate_to_method => 'handler', );
} qr/^You must supply the package_name and name parameters/;


lives_ok{ Foo->meta->remove_method('test') };
ok(!defined(Foo->can('test')),'Try call removed method ');
ok(!grep{/^test$/} Foo->meta->get_method_list,'Check removed_method');

Baz->meta->remove_method('foo1');
Baz->meta->remove_method('foo2');
Baz->meta->remove_method('foo3');
Baz->meta->remove_method('handler');
Baz->meta->remove_method('not_exist');

{
	package NoShaft;
	our $VERSION = '0.01';

	package Qux;
	use Shaft;
	no Shaft;
}
@Qux::ISA = qw(NoShaft Shaft::Object);
@methods = Qux->meta->get_all_methods;
ok @methods;

done_testing;