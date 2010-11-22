use strict;
use warnings;
use Test::More;
use Test::Exception;
{

	package Foo::Role;
	use Shaft::Role;

	requires 'var';

	sub test1 {
		return shift->var;
	}

	sub test2 {
		my $self = shift;
		return $self->var( $self->var * 2 );
	}

	sub test3 {
		my ( $self, $multi ) = @_;
		return $self->var( $self->var * $multi );
	}

	package Foo;
	use Shaft;

	has var => ( is => 'rw', isa => 'Int' );

	with 'Foo::Role';

	sub no_delegate {
		1;
	}

	package Bar;
	use Shaft;
	use Shaft::Util::TypeConstraints;

	coerce 'Foo' => from 'Int' => via { Foo->new( var => $_ ) };

	#Array
	Private foo1 => (
		is      => 'ro',
		isa     => 'Foo',
		coerce  => 1,
		handles => [qw/test1 test2 BUILD DEMOLISH rebless/]
	);

	#Hash
	Private foo2 => (
		is      => 'ro',
		isa     => 'Foo',
		coerce  => 1,
		handles => {
			'foo_test1' => 'test1',
			'foo_test2' => 'test2',
			'foo_test3' => sub{ my $self = shift; return $self->test1 + $self->test2 },
		},
	);

	#Curry
	Private foo3 => (
		is      => 'ro',
		isa     => 'Foo',
		coerce  => 1,
		handles => {
			'test3_1' => [qw/test3 3/],
			'test3_2' => [qw/test3 5/],
		},
	);

}

my $bar = Bar->new( foo1 => 1, foo2 => 2, foo3 => 1 );
can_ok( $bar, qw/test1 test2 foo_test1 foo_test2 foo_test3 test3_1 test3_2/ );

ok( $bar->test1 == 1 );
ok( $bar->test2 == 2 );
ok( $bar->foo_test1 == 2 );
ok( $bar->foo_test2 == 4 );
ok( $bar->foo_test3 == 6 );
ok( $bar->test3_1 == 3 );
ok( $bar->test3_2 == 15 );

my $method = $bar->meta->get_method('test1');
ok( ref $method eq 'Shaft::Meta::Method::Delegation' );
$method = $bar->meta->get_method('test2');
ok( ref $method eq 'Shaft::Meta::Method::Delegation' );
$method = $bar->meta->get_method('foo_test1');
ok( ref $method eq 'Shaft::Meta::Method::Delegation' );
ok( $method->delegate_to_method eq 'test1' );
$method = $bar->meta->get_method('foo_test2');
ok( ref $method eq 'Shaft::Meta::Method::Delegation' );
$method = $bar->meta->get_method('foo_test3');
ok( ref $method eq 'Shaft::Meta::Method::Delegation' );
ok( ref( $method->delegate_to_method) eq 'CODE' );
$method = $bar->meta->get_method('test3_1');
ok( ref $method eq 'Shaft::Meta::Method::Delegation' );
ok( $method->delegate_to_method eq 'test3' );
$method = $bar->meta->get_method('test3_2');
ok( ref $method eq 'Shaft::Meta::Method::Delegation' );
ok( $method->delegate_to_method eq 'test3' );

my $method2 = $method->clone;
ok( $method2->delegate_to_method eq $method->delegate_to_method );
ok( $method2->associated_attribute->name eq
		$method->associated_attribute->name );
ok( $method2->original_fully_qualified_name eq
		$method->original_fully_qualified_name );

throws_ok {
	Bar->meta->add_attribute( foo4 => { is => 'ro', isa => 'Foo', coerce => 1, handles => [qw/test1 test2/] }  );
} qr/You cannot overwrite a locally defined method \(test1\) with a delegation/;

$bar->meta->remove_attribute('foo1');
$bar->meta->remove_attribute('foo2');
$bar->meta->remove_attribute('foo3');

for my $name (qw/test1 test2 foo_test1 foo_test2 test3_1 test3_2/) {
	ok( !$bar->can($name) );
}

{

	package Baz1;
	use Shaft;

	#Regexp(isa)
	Private baz => (
		is      => 'ro',
		isa     => 'Foo',
		coerce  => 1,
		handles => qr/^test/
	);

	package Baz2;
	use Shaft;

	#Regexp2(does)
	Private baz => (
		is => 'ro',
		does => 'Foo::Role',
		default => sub { Foo->new( var => 1 ) },
		handles => qr/^test/,
	);

	package Baz3;
	use Shaft;

	#Code
	Private baz => (
		is      => 'ro',
		isa     => 'Foo',
		coerce  => 1,
		handles => sub {
			my ( $self, $meta ) = @_;
			return
				map { $_ => $_ }
				grep {/(?:test1|test3)/} $meta->get_method_list;
		},
	);

	package Baz4;
	use Shaft;

	#Role
	Private baz => (
		is      => 'ro',
		isa     => 'Foo',
		coerce  => 1,
		handles => 'Foo::Role',
	);
}

my $baz1 = Baz1->new( baz1 => 1 );
can_ok($baz1,qw/test1 test2 test3/);

my $baz2 = Baz2->new;
can_ok($baz2,qw/test1 test2 test3/);

my $baz3 = Baz3->new( baz => 1 );
can_ok($baz3,qw/test1 test3/);

my $baz4 = Baz4->new( baz => 1 );
can_ok($baz4,qw/test1 test2 test3/);

Baz1->meta->remove_attribute('baz');
Baz2->meta->remove_attribute('baz');
Baz3->meta->remove_attribute('baz');
Baz4->meta->remove_attribute('baz');

throws_ok {
	package Hoge;
	use Shaft;
	
	Private hoge => ( isa => 'Foo', handles => \(my $scalar) );
	
} qr/^Unable to canonicalize the 'handles' option with/;

throws_ok {
	package Fuga;
	use Shaft;
	
	Private fuga => ( isa => 'Foo', handles => 'NONE' );
	
} qr/^Unable to canonicalize the 'handles' option with NONE because : /;

throws_ok {
	package Fuga;
	use Shaft;
	
	Private fuga => ( isa => 'Foo', handles => 'Bar' );
	
} qr/^Unable to canonicalize the 'handles' option with Bar because ->meta is not a Shaft::Meta::Role/;

throws_ok {
	package Dummy;
	sub meta { 1 };
	
	package Fuga;
	use Shaft;
	
	Private fuga => ( isa => 'Foo', handles => 'Dummy' );
} qr/^Unable to canonicalize the 'handles' option with Dummy because ->meta is not a Shaft::Meta::Role/;

throws_ok {
	package Fuga;
	use Shaft;
	
	Private fuga => ( is => 'ro', handles => qr/^foo/ );
	
} qr/^Cannot delegate methods based on a Regexp without a type constraint \(isa\)/;

throws_ok {
	package Piyo;
	use Shaft;
	
	Private piyo => ( 
		is => 'ro',
		handles => sub {
			my ( $self, $meta ) = @_;
			return
				map { $_ => $_ }
				grep {/(?:test1|test3)/} $meta->get_method_list;
		},
	);
}qr/^Cannot find delegate metaclass for attribute/;


lives_ok {
	package A::Class;
	our $VERSION = '0.01';

	sub a1 { 1 }
	sub a2 { 1 }

	package B::Class;
	use Shaft -extends => 'A::Class';

	has 'foo' => ( 
		is => 'ro', 
		isa => 'Foo', 
		default => sub { Foo->new( var => 1 ) },
		handles => [qw/a1 a2/]
	 );
};

ok( B::Class->can('a1') );
ok( B::Class->can('a2') );
B::Class->meta->remove_method('a1');
B::Class->meta->remove_method('a2');

done_testing;
