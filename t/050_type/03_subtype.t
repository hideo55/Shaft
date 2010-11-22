use strict;
use warnings;
use Test::More;
use Test::Exception;
use Shaft::Util::TypeConstraints;

subtype 'UnsignedInt' => as 'Int' => where { $_ >= 0 } => optimize_as {
	defined( $_[0] ) && !ref( $_[0] ) && $_[0] =~ /^[0-9]+$/;
} => message {"You must supply unsigned integer value ($_[0])"};

my $type = find_type_constraint('UnsignedInt');

ok $type;
isa_ok $type, 'Shaft::Meta::TypeConstraint';
is $type->name, 'UnsignedInt';
is $type->message->(-1), "You must supply unsigned integer value (-1)";
ok $type->is_subtype_of('Int');
ok !$type->equals('Int');
ok $type->is_a_type_of('Int');

ok $type->equals('UnsignedInt');
ok $type->is_a_type_of('UnsignedInt');
ok !$type->is_subtype_of('UnsignedInt');

my $UNDEF   = undef;
my @BOOL    = ( 0, 1, "0", "1" );
my @POS_INT = ( 1, 2147483648 );
my @NEG_INT = ( -2147483647, -1 );
my @INT     = ( @POS_INT, @NEG_INT );
my @REAL    = (
	-255642.15476456,      -0.00000000000000000001,
	0.0000000000000000001, 324255.54543947
);
my @NUM        = ( @INT, @REAL );
my @STR        = qw/f azAZ09!d(0x0000)--/;
my @VALUE      = ( @BOOL, @NUM, @STR );
my $SCALARREF  = do { my $scalar; \$scalar; };
my $ARRAYREF   = [];
my $HASHREF    = {};
my $CODEREF    = sub {1};
my $REGEXPREF  = qr/^.*/;
my $SCALAR_REF = \( my $var );
no warnings 'once';
my $GLOB     = *GLOB_REF;
my $GLOB_REF = \$GLOB;
my $FILEHANDLE;
open( $FILEHANDLE, '<', $0 ) or die "Could not open $0 for the test";
my $FH_OBJ = bless {}, "IO::Handle";
{

	package Hoge;
	our $VERSION = '0.01';
}
my $OBJ_STD = bless {}, "Hoge";
my @NON_PRIMITIVE = (
	$SCALARREF, $ARRAYREF, $HASHREF,    $CODEREF, $REGEXPREF,
	$GLOB,      $GLOB_REF, $FILEHANDLE, $FH_OBJ,  $OBJ_STD
);

for (@POS_INT) {
	ok $type->check($_);
}
for ( $UNDEF, @NEG_INT, @STR, @REAL, @NON_PRIMITIVE ) {
	ok !$type->check($_);
}

subtype 'Str_10' => as find_type_constraint('Str') =>
	where { length($_) >= 10 };
ok( find_type_constraint('Str_10')->is_subtype_of('Str') );
$type = subtype 'Str_10_20' => as 'Str_10' => where { length($_) <= 20 };
ok $type->is_subtype_of('Str');
ok $type->is_subtype_of('Str_10');

ok $type->check( 'A' x 10 );
ok $type->check( 'A' x 20 );
ok !$type->check( 'A' x 9 );
ok !$type->check( 'A' x 21 );

my $type2 = subtype( undef, where => sub {1} );
is $type2->parent->name, 'Any';

lives_ok {
	subtype 'Foo' => as 'HashRef' => 'where' => undef;
};
ok( find_type_constraint('HashRef')->_compiled_type_constraint
		== find_type_constraint('Foo')->_compiled_type_constraint );

throws_ok {
	subtype 'Bar' => as 'Qux[Int]';
}
qr/^Support for parameterized types other than Maybe, ArrayRef or HashRef is not implemented yet/;


my $constraint = sub { 1 };
my $subtype1 = subtype 'Str1' => as 'Str' => optimize_as => $constraint;
my $subtype2 = subtype 'Str2' => as 'Str' => optimize_as => $constraint;
ok $subtype1->equals($subtype2);
my $subtype3 = subtype 'Str3' => as 'Ref' => optimize_as => $constraint;
ok !$subtype3->equals($subtype1);

my $anon1 = type( undef, where => sub{ 1 } );
my $anon2 = subtype(undef, as => $anon1, where => sub { ref($_[0]) } );
ok $anon2;
my $anon3 = $anon2->create_child_type( constraint => undef );
ok $anon3;

done_testing;
