use strict;
use warnings;
use Test::More;
use Test::Exception;
use Shaft::Util::TypeConstraints;
use List::MoreUtils qw/all/;

type 'Foo' => where { /^Foo_/ } => message { "You must be supply string which start with 'Foo_'" };
lives_ok {
	type 'Foo' => where { /^Foo_/ } => message { "You must be supply string which start with 'Foo_'" };
};

my $type = find_type_constraint('Foo');

ok $type;
isa_ok $type, 'Shaft::Meta::TypeConstraint';
is $type->name, 'Foo';
is "$type", 'Foo';
ok $type->has_message;
is $type->message->(), "You must be supply string which start with 'Foo_'";

ok $type->check('Foo_bar');
ok !$type->check('Foo bar');

type 'Bar' => where {/^Bar_/};

ok !find_type_constraint('Bar')->has_message;
is find_type_constraint('Bar')->get_message, q{Validation failed for 'Bar' failed with value 'undef'};

my %types = map{ $_ => find_type_constraint($_) } Shaft::Util::TypeConstraints::list_all_type_constraints();
ok all{ $_->isa('Shaft::Meta::TypeConstraint') } values %types;


throws_ok {
	type 'ArrayRef[HashRef]';
} qr/ArrayRef\[HashRef\] contains invalid characters for a type name./;

throws_ok {
	package Hoge;
	use Shaft;
	use Shaft::Util::TypeConstraints;
	
	type 'Foo';

} qr/The type constraint 'Foo' has already been created in/;

throws_ok {
	type 'Qux' => optimize => 'Qux';
} qr/^Optimized type constraint for Qux is not a code reference/;

$type = type 'Fuga' => 'where' => find_type_constraint('Defined');
ok( $type->constraint == find_type_constraint('Defined')->optimized_type_constraint);

my $anon1 = type undef,'where' => find_type_constraint('Int');
my $anon2 = type undef,'where' => find_type_constraint('Str');

is $anon1->name, '__ANON__';
is $anon2->name, '__ANON__';

ok !$anon1->is_a_type_of($anon2);
ok !$anon1->equals('__ANON__');
ok !$anon1->is_a_type_of('__ANON__');
ok !$anon1->is_subtype_of('__ANON__');

my $anon3 = Shaft::Meta::TypeConstraint->new();
is $anon3->name, '__ANON__';
ok $anon3->equals('Any');

my $anon4 = type( undef, where => sub{ 1 }  );
ok $anon4;
my $anon5 = type( undef, where => $anon4 );
ok $anon5;

{
	package A::Class;
	use Shaft;
}

throws_ok {
	Shaft::Meta::TypeConstraint->new(
		constraint => A::Class->new
	);
} qr/^You must supply CODE reference as constraint/;

{
	package A::Class;
	use Shaft;
}
is find_type_constraint(A::Class->new), undef;

done_testing;
