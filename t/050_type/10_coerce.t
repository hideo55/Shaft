use strict;
use warnings;
use Test::More;
use Test::Exception;
use Shaft::Util::TypeConstraints;

lives_ok{
coerce 'HashRef' 
	=> from 'Str' => via { +{ $_ => 1 } }
	=> from 'ArrayRef[Defined]' => via { +{ map{ $_ => 1 } @$_ } };
};

my $type = find_type_constraint('HashRef');
ok $type->has_coercion;
is_deeply( $type->coerce('Foo'),{ Foo => 1 });
is_deeply( $type->coerce([qw/1 Foo/]),{ 1 => 1, Foo => 1 });
is $type->coerce(undef),undef;


my $type2 = find_type_constraint('Object');

ok !$type2->has_coercion;

my $type3 = $type | $type2;

ok $type3->has_coercion;
is_deeply( $type3->coerce('Foo'),{ Foo => 1 });
is_deeply( $type3->coerce([qw/1 Foo/]),{ 1 => 1, Foo => 1 });;
is $type3->coerce(undef),undef;

throws_ok {
	coerce 'HashRef' 
		=> from 'Str' => via { +{ $_ => 1 } };
} qr/A coercion action already exists for 'Str'/;

throws_ok {
	coerce 'HashRef'
		=> from 'NOTEXISTS' => via{ +{} };
} qr/^Could not find the type constraint \(NOTEXISTS\) to coerce from/;

throws_ok {
	coerce $type3 
		=> from 'Int' => via { +{ $_ => 1 } };
} qr/^Cannot add additional type coercions to Union types/;

throws_ok {
	find_type_constraint('ArrayRef')->coerce({});
} qr/^Cannot coerce without a type coercion/;

throws_ok {
	coerce 'NOT_EXIST';
} qr/^Cannot find type 'NOT_EXIST', perhaps you forgot to load it./;

done_testing;
