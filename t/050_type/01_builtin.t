use strict;
use warnings;
use Test::More;
use Test::Exception;
use List::MoreUtils qw/all/;
use Shaft::Util::TypeConstraints;

my @builtin = qw/Any Item Undef Defined Bool Ref Value Str Num Int
	ScalarRef ArrayRef HashRef CodeRef RegexpRef GlobRef FileHandle Object
	ClassName RoleName/;

my $builtin_pattern = join( '|', @builtin );
$builtin_pattern = qr/^(?:$builtin_pattern)$/;

Shaft::Util::TypeConstraints->export_type_constraints_as_functions();

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

my @DEFINED = ( @VALUE, @NON_PRIMITIVE );


ok all {/$builtin_pattern/} Shaft::Util::TypeConstraints->list_all_builtin_type_constraints;

my $optimized = { map { $_ => find_type_constraint($_) }
		Shaft::Util::TypeConstraints->list_all_builtin_type_constraints };

ok all { $_->isa('Shaft::Meta::TypeConstraint') } values %$optimized;

ok !defined( $optimized->{Any}->message );
ok $optimized->{Any}->equals('Any');
ok $optimized->{Any}->is_a_type_of('Any');
ok !$optimized->{Any}->is_subtype_of('Any');
for my $type ( grep {/[^Any]/} @builtin ) {
	ok !$optimized->{$type}->equals('Any');
	ok $optimized->{$type}->is_a_type_of('Any');
	ok $optimized->{$type}->is_subtype_of('Any');
}

ok !defined( $optimized->{Item}->message );
ok $optimized->{Item}->equals('Item');
ok $optimized->{Item}->is_a_type_of('Item');
ok !$optimized->{Item}->is_subtype_of('Item');
ok !$optimized->{Any}->equals('Item');
ok !$optimized->{Any}->is_subtype_of('Item');
ok !$optimized->{Any}->is_a_type_of('Item');
for my $type ( grep {/[^Any|Item]/} @builtin ) {
	ok !$optimized->{$type}->equals('Item');
	ok $optimized->{$type}->is_a_type_of('Item');
	ok $optimized->{$type}->is_subtype_of('Item');
}

ok $optimized->{Undef}->equals('Undef');
ok $optimized->{Undef}->is_a_type_of('Undef');
for my $type ( grep {/[^Undef]/} @builtin ) {
	ok !$optimized->{$type}->is_a_type_of('Undef');
	ok !$optimized->{$type}->is_subtype_of('Undef');
}

ok $optimized->{Defined}->equals('Defined');
ok $optimized->{Defined}->is_a_type_of('Defined');
for my $type ( grep {/[^Any|Item|Undef|Defined]/} @builtin ) {
	ok $optimized->{$type}->is_a_type_of('Defined');
	ok $optimized->{$type}->is_subtype_of('Defined');
}
for my $type (qw/Any Item Undef/) {
	ok !$optimized->{$type}->is_a_type_of('Defined');
	ok !$optimized->{$type}->is_subtype_of('Defined');
}

ok $optimized->{Bool}->equals('Bool');
ok $optimized->{Bool}->is_a_type_of('Bool');

ok $optimized->{Ref}->equals('Ref');
ok $optimized->{Ref}->is_a_type_of('Ref');
for my $type (
	qw/ScalarRef ArrayRef HashRef CodeRef RegexpRef GlobRef FileHandle Object/
	)
{
	ok $optimized->{$type}->is_a_type_of('Ref');
	ok $optimized->{$type}->is_subtype_of('Ref');
}

ok $optimized->{ScalarRef}->equals('ScalarRef');
ok $optimized->{ScalarRef}->is_a_type_of('ScalarRef');

#Any
for my $value ( ( @DEFINED, $UNDEF ) ) {
	ok( Any($value) );
}

#Undef
ok( Undef($UNDEF) );
for my $value (@VALUE) {
	ok !Undef($value);
}

#Defined
for my $value (@DEFINED) {
	ok( Defined($value) );
}
ok !Defined(undef);

for my $value (@BOOL){
	ok( Bool($value) );
}
ok Bool(undef);
ok Bool('');
ok !Bool('str');
ok !Bool($_) for @NON_PRIMITIVE;

#Value
for my $value (@VALUE) {
	ok( Value($value) );
}
for my $value ( ( @NON_PRIMITIVE, $UNDEF ) ) {
	ok !Value($value);
}

#Num
for my $value (@NUM) {
	ok( Num($value) );
}
for my $value ( @STR, @NON_PRIMITIVE, $UNDEF ) {
	ok !Num($value);
}

#Int
for my $value (@INT) {
	ok( Int($value) );
}
for my $value ( @REAL, @STR, @NON_PRIMITIVE, $UNDEF ) {
	ok !Int($value);
}

#Str
for my $value (@VALUE) {
	ok( Str($value) );
}
for my $value ( @NON_PRIMITIVE, $UNDEF ) {
	ok !Str($value);
}

#ClassName
for my $value ( @CLASS_NAME, $ROLE_NAME ) {
	ok( ClassName($value) );
}
for my $value ( @DEFINED, $UNDEF ) {
	ok !ClassName($value);
}

#RoleName
ok( RoleName($ROLE_NAME) );
for my $value ( @DEFINED, $UNDEF, @CLASS_NAME ) {
	ok !RoleName($value);
}

#Ref
for my $value (
	$SCALARREF, $ARRAYREF,   $HASHREF, $CODEREF, $REGEXPREF,
	$GLOB_REF,  $FILEHANDLE, $FH_OBJ,  $OBJECT,  $ROLE
	)
{
	ok( Ref($value) );
}
for my $value ( @VALUE, $GLOB, $UNDEF ) {
	ok !Ref($value);
}

#ScalarRef
ok( ScalarRef($SCALARREF) );
for my $value (
	@VALUE,  $ARRAYREF, $HASHREF,    $CODEREF, $REGEXPREF,
	$GLOB,   $GLOB_REF, $FILEHANDLE, $FH_OBJ,  $OBJ_STD,
	$OBJECT, $ROLE,     $UNDEF
	)
{
	ok !ScalarRef($value);

}

#ArrayRef
ok( ArrayRef($ARRAYREF) );
for my $value (
	@VALUE,  $SCALARREF, $HASHREF,    $CODEREF, $REGEXPREF,
	$GLOB,   $GLOB_REF,  $FILEHANDLE, $FH_OBJ,  $OBJ_STD,
	$OBJECT, $ROLE,      $UNDEF
	)
{
	ok !ArrayRef($value);
}

#HashRef
ok( HashRef($HASHREF) );
for my $value (
	@VALUE,  $SCALARREF, $ARRAYREF,   $CODEREF, $REGEXPREF,
	$GLOB,   $GLOB_REF,  $FILEHANDLE, $FH_OBJ,  $OBJ_STD,
	$OBJECT, $ROLE,      $UNDEF
	)
{
	ok !HashRef($value);
}

#CodeRef
ok( CodeRef($CODEREF) );
for my $value (
	@VALUE,  $SCALARREF, $ARRAYREF,   $HASHREF, $REGEXPREF,
	$GLOB,   $GLOB_REF,  $FILEHANDLE, $FH_OBJ,  $OBJ_STD,
	$OBJECT, $ROLE,      $UNDEF
	)
{
	ok !CodeRef($value);
}

#RegexpRef
ok( RegexpRef($REGEXPREF) );
for my $value (
	@VALUE,  $SCALARREF, $ARRAYREF,   $HASHREF, $CODEREF,
	$GLOB,   $GLOB_REF,  $FILEHANDLE, $FH_OBJ,  $OBJ_STD,
	$OBJECT, $ROLE,      $UNDEF
	)
{
	ok !RegexpRef($value);
}

#GlobRef
ok( GlobRef($GLOB_REF) );
ok( GlobRef($FILEHANDLE) );
for my $value (
	@VALUE, $SCALARREF, $ARRAYREF, $HASHREF, $CODEREF, $REGEXPREF,
	$GLOB,  $FH_OBJ,    $OBJ_STD,  $OBJECT,  $ROLE,    $UNDEF
	)
{
	ok !GlobRef($value);
}

#FileHandle
ok( FileHandle($FILEHANDLE) );
ok( FileHandle($FH_OBJ) );
for my $value (
	@VALUE, $SCALARREF, $ARRAYREF, $HASHREF, $CODEREF, $REGEXPREF,
	$GLOB,  $GLOB_REF,  $OBJ_STD,  $OBJECT,  $ROLE,    $UNDEF
	)
{
	ok !FileHandle($value);
}

#Object
for my $value ( $FH_OBJ, $OBJ_STD, $OBJECT, $ROLE ) {
	ok( Object($value) );
}
for my $value (
	@VALUE, $SCALARREF, $ARRAYREF,   $HASHREF, $CODEREF,
	$GLOB,  $GLOB_REF,  $FILEHANDLE, $UNDEF
	)
{
	ok !Object($value);
}

for my $name ( @builtin ){
	Data::Util::uninstall_subroutine( __PACKAGE__, $name );
}

done_testing;
