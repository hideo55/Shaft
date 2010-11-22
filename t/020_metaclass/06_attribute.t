use strict;
use warnings;
use Test::More;
use Test::Exception;
use Shaft::Util::TypeConstraints;

{
	package Foo;
	use Shaft;
	
	package Shaft::Meta::Attribute::Custom::Trait::Foo;
	use Shaft::Role;
}

coerce 'Int' => from 'Str' => via { length($_) };

my $foo = Foo->new;
$foo->meta->add_attribute(foo => { modifier => 'Public' ,is => 'rw', isa => 'Int', traits => ['Foo'] , coerce => 1 } );
$foo->foo(1);
cmp_ok($foo->foo,'==', 1,'Add');
isa_ok $foo->meta->get_attribute('foo'),'Shaft::Meta::Attribute';
isa_ok $foo->meta->get_method('foo'),'Shaft::Meta::Method::Accessor';
is $foo->meta->get_method('foo')->associated_attribute->name,'foo';

my $attr = $foo->meta->get_attribute('foo');
ok $attr;
ok $attr->get_read_method_ref;
ok $attr->get_write_method_ref;
ok $attr->does('Foo');
ok $attr->does('Shaft::Meta::Attribute::Custom::Trait::Foo');
$attr->verify_against_type_constraint(1);
dies_ok { $attr->verify_against_type_constraint({}) };
is $attr->coerce_constraint('foo'), 3;

$foo->meta->remove_attribute('foo');
ok(!defined(Foo->new->can('foo')),'Try call removed attribute accessor ');
ok(!grep{/^foo$/} Foo->meta->get_attribute_list,'Check removed_attribue');

is $foo->meta->remove_attribute('bar'), undef;

ok $foo->meta->add_attribute('bar');

{
	package Bar;
	use Shaft;

	Public bar => ( is => 'rw' );
	
	package Baz;
	use Shaft;
	extends 'Bar';
	
	Public baz => ( is => 'rw' );
}

$attr = Baz->meta->find_attribute_by_name('bar');
ok $attr;
is $attr->name,'bar';
is $attr->associated_class->name,'Bar';

$attr = Baz->meta->find_attribute_by_name('baz');
ok $attr;
is $attr->name,'baz';
is $attr->associated_class->name,'Baz';

throws_ok{
	package Qux;
	use Shaft;
	
	Qux->meta->add_attribute();
}qr/^You must provide a name for the attribute/;

{
	package Quxx1;
	use Shaft;
	has 'attr1' => ( is => 'rw' );

	package Quxx2;
	our $VERSION = '0.01';
	our @ISA = qw(Quxx1);

	package Quxx3;
	use Shaft;
	our @ISA = qw(Quxx2);
}
ok( Quxx3->meta->find_attribute_by_name('attr1') );

done_testing;