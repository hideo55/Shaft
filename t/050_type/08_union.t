use strict;
use warnings;
use Test::More;
use Test::Exception;
use Shaft::Util::TypeConstraints;

my $array = find_type_constraint('ArrayRef');
my $hash  = find_type_constraint('HashRef');

ok !$array->is_union;
ok !$hash->is_union;
my @tc = $hash->type_constraints;
is scalar(@tc), 0;

my $union = $array | $hash;
is $union->name, "ArrayRef|HashRef";
is "$union", "ArrayRef|HashRef";
ok $union->is_union;
is scalar($union->type_constraints), 2;

ok !$union->equals($array);
ok !$union->equals($hash);
ok $union->is_a_type_of($array);
ok $union->is_a_type_of($hash);
ok $union->is_subtype_of($array);
ok $union->is_subtype_of($hash);

{

	package Foo;
	use Shaft;

	package Bar::Role;
	use Shaft::Role;

	package Bar;
	use Shaft;
	with 'Bar::Role';

	package Hoge;
	our $VERSION = '0.01';
}

my $UNDEF   = undef;
my @BOOL    = ( 0, 1, "0", "1" );
my @POS_INT = ( 1, 2147483648 );
my @NEG_INT = ( -2147483647, -1 );
my @INT     = ( @POS_INT, @NEG_INT );
my @REAL    = (
	-255642.15476456,  -0.00000000000000000001, 0.0000000000000000001,
	324255.54543947
);
my @NUM       = ( @INT, @REAL );
my @STR       = qw/f azAZ09!d(0x0000)--/;
my @VALUE     = ( @BOOL, @NUM, @STR );
my $SCALARREF = do { my $scalar; \$scalar; };
my $ARRAYREF  = [];
my $HASHREF   = {};
my $CODEREF   = sub {1};
my $REGEXPREF = qr/^.*/;
no warnings 'once';
my $GLOB     = *GLOB_REF;
my $GLOB_REF = \$GLOB;
my $FILEHANDLE;
open( $FILEHANDLE, '<', $0 ) or die "Could not open $0 for the test";
my $FH_OBJ  = bless {}, "IO::Handle";
my $OBJ_STD = bless {}, "Hoge";
my @CLASS_NAME = qw/Shaft Foo Bar Hoge/;
my $ROLE_NAME  = 'Bar::Role';
my $OBJECT     = Foo->new;
my $ROLE       = Bar->new;

my @NON_PRIMITIVE = (
	$SCALARREF, $ARRAYREF, $HASHREF,  $CODEREF,
	$REGEXPREF, $GLOB,     $GLOB_REF, $FILEHANDLE,
	$FH_OBJ,    $OBJ_STD,  $OBJECT,   $ROLE
);

for my $value ( $ARRAYREF, $HASHREF ) {
	ok $union->check($value);
}
for my $value (
	@VALUE,     $SCALARREF,  $CODEREF, $REGEXPREF, $GLOB,
	$GLOB_REF,  $FILEHANDLE, $FH_OBJ,  $OBJ_STD,   @CLASS_NAME,
	$ROLE_NAME, $OBJECT,     $ROLE,    $UNDEF
	)
{
	ok !$union->check($value);
}

my $pt_union = Shaft::Util::TypeConstraints::find_or_create_type_constraint('Int|ArrayRef[Int]|HashRef[Int]');
isa_ok $pt_union, 'Shaft::Meta::TypeConstraint';
ok $pt_union->is_subtype_of('Int');
ok $pt_union->is_subtype_of('ArrayRef');
ok $pt_union->is_subtype_of('HashRef');
ok $pt_union->is_subtype_of('ArrayRef[Int]');
ok $pt_union->is_subtype_of('HashRef[Int]');

done_testing;
