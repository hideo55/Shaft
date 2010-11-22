use strict;
use warnings;
use Test::More tests => 25;
use Shaft::Util::TypeConstraints ();

my $pt1 = Shaft::Util::TypeConstraints::find_or_create_type_constraint('ArrayRef[Int]');
isa_ok $pt1, 'Shaft::Meta::TypeConstraint';
ok $pt1->is_subtype_of('ArrayRef');
ok !$pt1->is_subtype_of('Int');
ok $pt1->check([1..5]);
ok !$pt1->check([qw/foo bar baz/]);
ok !$pt1->check({});
ok $pt1->is_parameterized;
ok $pt1->type_parameter->equals('Int');

my $pt2 = Shaft::Util::TypeConstraints::find_or_create_type_constraint('HashRef[Int]');
isa_ok $pt2, 'Shaft::Meta::TypeConstraint';
ok $pt2->is_subtype_of('HashRef');
ok !$pt2->is_subtype_of('Int');
ok $pt2->check({ foo => 1, bar => 1, baz => 1 });
ok !$pt2->check({ foo => 'foo', bar => 'bar', baz => 'baz' });
ok !$pt2->check([]);
ok $pt2->is_parameterized;
ok $pt2->type_parameter->equals('Int');

my $pt3 = Shaft::Util::TypeConstraints::find_or_create_type_constraint('Maybe[Int]');
isa_ok $pt3, 'Shaft::Meta::TypeConstraint';
ok $pt3->is_subtype_of('Item');
ok !$pt3->is_subtype_of('Int');
ok $pt3->check(100);
ok $pt3->check(undef);
ok !$pt3->check('foo');
ok $pt3->is_parameterized;
ok $pt3->type_parameter->equals('Int');

my $pt4 = Shaft::Util::TypeConstraints::find_or_create_type_constraint('ArrayRef[Int]');
$pt4->equals($pt1);
$pt4 = Shaft::Util::TypeConstraints::find_or_create_type_constraint('ArrayRef[Int]|');
$pt4->equals($pt1);

ok !Shaft::Util::TypeConstraints::find_type_constraint('Int')->is_parameterized;

__END__