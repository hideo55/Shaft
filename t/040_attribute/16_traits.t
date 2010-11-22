use strict;
use warnings;
use Test::More tests => 16;
use Test::Exception;

{
	package Shaft::Meta::Attribute::Custom::Trait::Foo1;
	use Shaft::Role;
	
	has 'attr1' => ( is => 'ro' );

	sub foo1 { 1 }

	no Shaft::Role;

	package ShaftX::Foo2::Meta::Attribute;
	{

		package Shaft::Meta::Attribute::Custom::Trait::Foo2;

		sub register_implementation {
			'ShaftX::Foo2::Meta::Attribute';
		}

	}
	use Shaft::Role;
	
	has 'attr2' => ( is => 'ro' );
	
	sub foo2 { 1 }

	no Shaft::Role;

	package Trait::Foo3;
	use Shaft::Role;
	
	has 'attr3' => ( is => 'ro' );
	
	sub foo3 { 1 }
	
	no Shaft::Role;
}

{
	package Foo;
	use Shaft;

	has foo => (
		is     => 'rw',
		traits => [ 'Foo1', 'Foo2', { -alias => { foo2 => 'foo2_2' } }, 'Trait::Foo3' ],
	);
	
	has bar => ( is => 'rw', traits => [] );

	no Shaft;
	__PACKAGE__->meta->make_immutable;
}

my $attr = Foo->meta->get_attribute('foo');
isa_ok $attr, 'Shaft::Meta::Attribute';
ok $attr->meta->is_anon_class;
ok $attr->does('Foo1');
ok $attr->does('Shaft::Meta::Attribute::Custom::Trait::Foo1');
ok $attr->does('Foo2');
ok $attr->does('Shaft::Meta::Attribute::Custom::Trait::Foo2');
ok $attr->does('ShaftX::Foo2::Meta::Attribute');
ok $attr->does('Trait::Foo3');
ok !$attr->does('Foo3');

can_ok $attr, qw(foo1 foo2 foo2_2 foo3 attr1 attr2 attr3);

my $metaclass1 = Shaft::Meta::Attribute->interpolate_class({ traits => [qw/Foo1 Foo2/] });
my ($metaclass2,@traits) = Shaft::Meta::Attribute->interpolate_class({ traits => [qw/Foo1 Foo2/] });
is $metaclass1, $metaclass2;
is_deeply \@traits, [qw/Shaft::Meta::Attribute::Custom::Trait::Foo1 ShaftX::Foo2::Meta::Attribute/];

{
	package Bar::Meta::Attribute;
	
	{
		package Shaft::Meta::Attribute::Custom::Bar2;
		sub register_implementation {
			'Bar::Meta::Attribute';
	 	}
	}

	use Shaft -extends => 'Shaft::Meta::Attribute';
	with 'Trait::Foo3';
	no Shaft;
	__PACKAGE__->meta->make_immutable;

	package Bar;
	use Shaft;

	has bar => ( is => 'rw', metaclass => 'Bar2', traits => [qw/Foo1 Trait::Foo3/] );
	
}

dies_ok{
	package Baz;
	use Shaft;

	has baz => ( is => 'rw', traits => [qw/Class::NOT::EXIST/] );
};

{
	package Qux;
	use Shaft;
	extends 'Foo';

	has '+bar' => ( traits => [qw/Foo1/] );
}
$attr = Foo->meta->get_attribute('foo');
isa_ok $attr, 'Shaft::Meta::Attribute';
ok $attr->meta->is_anon_class;
ok $attr->does('Foo1');

__END__