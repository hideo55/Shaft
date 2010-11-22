use strict;
use warnings;
use Test::More;
use Test::Exception;
use Shaft::Util::TypeConstraints;

my $anon = enum [qw/Foo Bar Baz/];
ok $anon =~ /^__ANON__$/;
ok $anon->is_subtype_of('Str');

my $anon2 = enum [qw/Foo Bar Baz/];
ok $anon->equals($anon2);

my @numbers = qw/One Two Three Four Five Six Seven Eight Nine Ten/;

enum Numbers => @numbers;

my $enum = find_type_constraint('Numbers');
is "$enum", 'Numbers';

ok !$enum->equals($anon);
ok !$enum->is_subtype_of($anon);
ok !$anon->equals($enum);
ok !$anon->is_subtype_of($enum);

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
my @VALUE = ( @BOOL, @NUM, @STR );
my $SCALARREF = do { my $scalar; \$scalar; };
my $ARRAYREF  = [];
my $HASHREF   = {};
my $CODEREF   = sub {1};
my $REGEXPREF = qr/^.*/;
my $SCALAR_REF = \(my $var);
no warnings 'once';
my $GLOB     = *GLOB_REF;
my $GLOB_REF = \$GLOB;
my $FILEHANDLE;
open( $FILEHANDLE, '<', $0 ) or die "Could not open $0 for the test";
my $FH_OBJ  = bless {}, "IO::Handle";
{
	package Hoge;
	our $VERSION = '0.01';
}
my $OBJ_STD = bless {}, "Hoge";
my @NON_PRIMITIVE = (
	$SCALARREF, $ARRAYREF, $HASHREF,  $CODEREF,
	$REGEXPREF, $GLOB,     $GLOB_REF, $FILEHANDLE,
	$FH_OBJ,    $OBJ_STD
);


for(@numbers){
	ok $enum->check($_);
}
for($UNDEF,@VALUE,@NON_PRIMITIVE){
	ok ! $enum->check($_);
}

throws_ok {
	enum();
} qr/^You must have at least two values to enumerate through/;

throws_ok {
	enum('Foo');
} qr/^You must have at least two values to enumerate through/;

throws_ok {
	enum('Foo',{});
} qr/^You must have at least two values to enumerate through/;

done_testing;
