use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo::Role1;
	use Shaft::Role;
	
	requires 'bar';
	
	Public '+foo' => ( default => 10 );
	
	sub baz1 : Private { 1 }
	
	package Foo::Role2;
	use Shaft::Role;
	
	with 'Foo::Role1';
	
	sub bar {
		1;
	}
	
	package Foo;
	use Shaft;
	
	Public foo => ( is => 'rw' );
	
	with 'Foo::Role2';
};

my $foo = Foo->new;
ok $foo->meta->does_role('Foo::Role1');
ok $foo->meta->does_role('Foo::Role2');
ok(Foo::Role2->meta->does_role('Foo::Role1') );
is $foo->foo, 10;
can_ok( $foo, 'bar', 'baz1');

my $meta = Foo::Role2->meta;
my $roles = $meta->roles;
my @roles = map{ $_->name } @$roles;
is_deeply(\@roles,['Foo::Role1']);
@roles = map { $_->name } $meta->roles;
is_deeply(\@roles,['Foo::Role1']);

dies_ok{ $foo->baz1 };

my ($attr) = Foo::Role2->meta->get_method_attributes_by_method('baz1');
ok $attr;
is $attr->attribute_name,'Private';

($attr) = Foo::Role1->meta->get_method_attributes_by_method('baz1');
ok $attr;
is $attr->attribute_name,'Private';

($attr) = Foo->meta->get_method_attributes_by_method('baz1');
ok $attr;
is $attr->attribute_name,'Private';

done_testing;