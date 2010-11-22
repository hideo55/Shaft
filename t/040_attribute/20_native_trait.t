use strict;
use warnings;
use Test::More tests => 145;
use Test::Exception;

# Number
my %method_map = map { 
	my $key = $_ . '_foo';
	$key => $_
} qw(set add sub mul div mod abs);

{
	package Foo1;
	use Shaft;

	has 'foo1' => ( 
		is => 'rw', 
		isa => 'Int', 
		traits => ['Number'], 
		handles => {%method_map},
	);

	has 'foo2' => (
		is => 'rw',
		traits => ['Number'],
		handles => {},
	);
}

can_ok('Foo1',keys %method_map);
my $foo = Foo1->new( foo1 => 10 );
is $foo->add_foo(5), 15;
is $foo->sub_foo(20), -5;
is $foo->mul_foo(2), -10;
is $foo->div_foo(5), -2;
is $foo->abs_foo, 2;
is $foo->set_foo(1), 1;

ok $foo->meta->get_attribute('foo2')->type_constraint->equals('Num');

# Bool
%method_map = map { 
	my $key = $_ . '_foo';
	$key => $_
} qw(set unset toggle not);

{
	package Foo2;
	use Shaft;

	has 'foo1' => ( 
		is => 'rw', 
		isa => 'Bool', 
		traits => ['Bool'], 
		handles => {%method_map},
	);

	has 'foo2' => (
		traits => ['Bool'],
		handles => {},
	);
}

can_ok('Foo2',keys %method_map);
my $foo2 = Foo2->new;
ok $foo2->set_foo;
ok !$foo2->unset_foo;
ok $foo2->toggle_foo;
ok !$foo2->toggle_foo;
ok $foo2->not_foo;

my $attr = $foo2->meta->get_attribute('foo2');
ok $attr->is_rw;
ok $attr->type_constraint->equals('Bool');

# String
%method_map = map { 
	my $key = $_ . '_foo';
	$key => $_
} qw(append prepend replace match chop chomp inc clear length substr);

{
	package Foo3;
	use Shaft;

	has 'foo' => ( 
		is => 'rw', 
		isa => 'Str', 
		traits => ['String'], 
		handles => {%method_map},
	);

	has 'foo2' => (
		is => 'rw',
		traits => ['String'],
		handles => {},
	);
}

can_ok('Foo3',keys %method_map);

my $foo3 = Foo3->new;
$foo3->foo('bar');
is $foo3->append_foo('baz'), 'barbaz';
is $foo3->prepend_foo('foo'), 'foobarbaz';
is $foo3->replace_foo('bar',sub{ 'foo' }), 'foofoobaz';
is $foo3->replace_foo('baz','bar'), 'foofoobar';
ok $foo3->match_foo('foobar');
ok $foo3->match_foo(qr/bar/);
ok !$foo3->match_foo('baz');
is $foo3->chop_foo, 'foofooba';
$foo3->append_foo("\n\n");
is $foo3->chomp_foo, "foofooba\n";
is $foo3->chomp_foo, "foofooba";
is $foo3->inc_foo, 'foofoobb';
is $foo3->inc_foo, 'foofoobc';
is $foo3->clear_foo, '';
is $foo3->length_foo, 0;
$foo3->foo('foobarbaz');
is $foo3->length_foo, 9;
is $foo3->substr_foo(3,3),'bar';
is $foo3->substr_foo(), 'foobarbaz';
is $foo3->substr_foo(2), 'obarbaz';
is $foo3->substr_foo(1,-1,'foo'), 'oobarba';

$attr = $foo3->meta->get_attribute('foo2');
is $attr->default, '';
ok $attr->type_constraint->equals('Str');


# Counter
%method_map = map { 
	my $key = $_ . '_foo';
	$key => $_
} qw(set reset inc dec);


{
	package Foo4;
	use Shaft;

	has 'foo' => ( 
		is => 'rw', 
		isa => 'Int', 
		default => 10,
		traits => ['Counter'],
		handles => {%method_map},
	);

	has 'foo2' => (
		traits => ['Counter'],
		handles => {},
	);

}

can_ok('Foo4',keys %method_map);
my $foo4 = Foo4->new();
is $foo4->inc_foo(), 11;
is $foo4->inc_foo(10), 21;
is $foo4->dec_foo(), 20;
is $foo4->dec_foo(5), 15;
is $foo4->set_foo(2), 2;
is $foo4->reset_foo(), 10;

$attr = $foo4->meta->get_attribute('foo2');
ok $attr->is_ro;
is $attr->default, 0;
ok $attr->type_constraint->equals('Num');


# Array
%method_map = map { 
	my $key = $_ . '_foo';
	$key => $_
} qw(count is_empty first map reduce sort shuffle grep uniq elements join push pop 
shift unshift get set accessor clear delete insert splice sort_in_place natatime);


{
	package Foo5;
	use Shaft;

	has 'foo' => (
		is => 'rw',
		isa => 'ArrayRef',
		default => sub { +[] },
		traits => ['Array'],
		handles => {%method_map},
	);

	has 'foo2' => (
		is => 'rw',
		isa => 'ArrayRef[Int]',
		default => sub { +[] },
		traits => ['Array'],
		handles => {
			push_foo2 => 'push',
			unshift_foo2 => 'unshift',
			set_foo2 => 'set',
			access_foo2 => 'accessor',
			insert_foo2 => 'insert',
			splice_foo2 => 'splice',
		},
	);

	has 'foo3' => (
		traits => ['Array'],
		handles => {},
	);
}

can_ok('Foo5',keys %method_map);

my $foo5 = Foo5->new;

is $foo5->count_foo, 0;
ok $foo5->is_empty_foo;
$foo5->push_foo(qw/foo bar baz foo2 bar2 baz2/);
is_deeply($foo5->foo,[qw/foo bar baz foo2 bar2 baz2/]);
is $foo5->count_foo, 6;
ok !$foo5->is_empty_foo;
my $joined = $foo5->join_foo('-');
is $joined, 'foo-bar-baz-foo2-bar2-baz2';
my $elm = $foo5->pop_foo;
is $elm, 'baz2';
is_deeply($foo5->foo,[qw/foo bar baz foo2 bar2/]);
$elm = $foo5->shift_foo;
is $elm, 'foo';
is_deeply($foo5->foo,[qw/bar baz foo2 bar2/]);
$foo5->unshift_foo($elm);
is_deeply($foo5->foo,[qw/foo bar baz foo2 bar2/]);
$elm = $foo5->first_foo(sub{ length($_) > 3 });
is $elm, 'foo2';
my @ar1 = $foo5->map_foo(sub{ uc($_) });
is_deeply(\@ar1,[qw/FOO BAR BAZ FOO2 BAR2/]);
my $res = $foo5->reduce_foo(sub{ $_[0] . $_[1] });
is $res, 'foobarbazfoo2bar2';
@ar1 = $foo5->elements_foo;
is_deeply(\@ar1,[qw/foo bar baz foo2 bar2/]);
@ar1 = $foo5->sort_foo;
is_deeply(\@ar1,[qw/bar bar2 baz foo foo2/]);
@ar1 = $foo5->sort_foo(sub{ lc $_[1] cmp lc $_[0] });
is_deeply(\@ar1,[qw/foo2 foo baz bar2 bar/]);
throws_ok{
	$foo5->sort_foo({});
} qr/^Argument must be a code reference/;
@ar1 = $foo5->grep_foo(sub{ length($_) > 3 });
is_deeply(\@ar1,[qw/foo2 bar2/]);
is $foo5->get_foo(2), 'baz';
$foo5->set_foo(5,'baz2');
is_deeply($foo5->foo,[qw/foo bar baz foo2 bar2 baz2/]);
$foo5->accessor_foo(6,'foo');
is_deeply($foo5->foo,[qw/foo bar baz foo2 bar2 baz2 foo/]);
is $foo5->accessor_foo(1), 'bar';
throws_ok{
	$foo5->accessor_foo(1,2,3);
} qr/^One or two arguments expected, not/;
@ar1 = $foo5->uniq_foo;
is_deeply(\@ar1,[qw/foo bar baz foo2 bar2 baz2/]);
$foo5->delete_foo(6);
is_deeply($foo5->foo,[qw/foo bar baz foo2 bar2 baz2/]);
$foo5->insert_foo(3,'foo');
is_deeply($foo5->foo,[qw/foo bar baz foo foo2 bar2 baz2/]);
@ar1 = ();
$foo5->natatime_foo(3,sub{ push @ar1, join('_',@_); });
is_deeply(\@ar1,[qw/foo_bar_baz foo_foo2_bar2 baz2/]);
$foo5->sort_in_place_foo;
is_deeply($foo5->foo,[qw/bar bar2 baz baz2 foo foo foo2/]);
$foo5->sort_in_place_foo(sub{ lc $_[1] cmp lc $_[0]  });
is_deeply($foo5->foo,[qw/foo2 foo foo baz2 baz bar2 bar/]);
throws_ok{
	$foo5->sort_in_place_foo({});
} qr/^Argument must be a code reference/;
@ar1 = $foo5->splice_foo(4,2);
is_deeply($foo5->foo,[qw/foo2 foo foo baz2 bar/]);
is_deeply(\@ar1,[qw/baz bar2/]);
$foo5->splice_foo(1,2,'hoge','fuga');
is_deeply($foo5->foo,[qw/foo2 hoge fuga baz2 bar/]);

$foo5->shuffle_foo;
ok eq_array($foo5->foo,[qw/foo2 hoge fuga baz2 bar/]);

$foo5->clear_foo;
ok $foo5->is_empty_foo;
is $foo5->count_foo, 0;
is_deeply($foo5->foo,[]);

$foo5->push_foo2(1..10);
is_deeply($foo5->foo2,[1..10]);
throws_ok {
	$foo5->push_foo2('foo');
} qr/Value foo did not pass container type constraint 'Int'/;
throws_ok {
	$foo5->push_foo2(undef);
} qr/Value undef did not pass container type constraint 'Int'/;

$foo5->unshift_foo2(0);
is_deeply($foo5->foo2,[0..10]);
throws_ok {
	$foo5->unshift_foo2('foo');
} qr/Value foo did not pass container type constraint 'Int'/;
throws_ok {
	$foo5->unshift_foo2(undef);
} qr/Value undef did not pass container type constraint 'Int'/;

$foo5->set_foo2(11,11);
is_deeply($foo5->foo2,[0..11]);
throws_ok {
	$foo5->set_foo2(1,'foo');
} qr/Value foo did not pass container type constraint 'Int'/;
throws_ok {
	$foo5->set_foo2(1,undef);
} qr/Value undef did not pass container type constraint 'Int'/;

$foo5->access_foo2(12,12);
is_deeply($foo5->foo2,[0..12]);
throws_ok {
	$foo5->access_foo2(1,'foo');
} qr/Value foo did not pass container type constraint 'Int'/;
throws_ok {
	$foo5->access_foo2(1,undef);
} qr/Value undef did not pass container type constraint 'Int'/;

$foo5->insert_foo2(1,2);
is_deeply($foo5->foo2,[qw/0 2 1 2 3 4 5 6 7 8 9 10 11 12/]);
throws_ok {
	$foo5->insert_foo2(1,'foo');
} qr/Value foo did not pass container type constraint 'Int'/;
throws_ok {
	$foo5->insert_foo2(1,undef);
} qr/Value undef did not pass container type constraint 'Int'/;

$foo5->splice_foo2(1,2,1,2);
is_deeply($foo5->foo2,[qw/0 1 2 2 3 4 5 6 7 8 9 10 11 12/]);
throws_ok {
	$foo5->splice_foo2(1,1,'foo');
} qr/Value foo did not pass container type constraint 'Int'/;
throws_ok {
	$foo5->splice_foo2(1,1,undef);
} qr/Value undef did not pass container type constraint 'Int'/;

ok $foo5->meta->get_attribute('foo3')->type_constraint('ArrayRef');


# Hash
%method_map = map { 
	my $key = $_ . '_foo';
	$key => $_
} qw(exists defined get set accessor keys values kv elements count is_empty clear delete);

{
	package Foo6;
	use Shaft;

	has 'foo' => (
		is => 'rw',
		isa => 'HashRef',
		default => sub { +{} },
		traits => ['Hash'],
		handles => {%method_map},
	);

	has 'foo2' => (
		is => 'rw',
		isa => 'HashRef[Str]',
		default => sub { +{} },
		traits => ['Hash'],
		handles => {
			set_foo2 => 'set',
			access_foo2 => 'accessor',
		},
	);

	has 'foo3' => (
		traits => ['Hash'],
		handles => {},
	);
}

can_ok('Foo6',keys %method_map);

my $foo6 = Foo6->new();

ok $foo6->is_empty_foo;

is $foo6->count_foo, 0;

$foo6->foo({ foo => 1, bar => undef });

ok !$foo6->is_empty_foo;

is $foo6->count_foo, 2;

ok $foo6->exists_foo('foo');
ok $foo6->exists_foo('bar');
ok !$foo6->exists_foo('baz');

ok $foo6->defined_foo('foo');
ok !$foo6->defined_foo('bar');
ok !$foo6->defined_foo('baz');

is $foo6->get_foo('foo'), 1;
my @get = $foo6->get_foo(qw/foo bar/);
is_deeply(\@get,[1,undef]);

$foo6->set_foo( 'baz' => 2 );
is $foo6->foo->{baz}, 2;
$foo6->set_foo( foo2 => 'foo2' , bar2 => 'bar2' , baz2 =>'baz2' );
is_deeply($foo6->foo,{ 
	foo => 1,
	foo2 => 'foo2',
	bar => undef,
	bar2 => 'bar2',
	baz => 2,
	baz2 => 'baz2',
});

$foo6->delete_foo('foo2');
ok !exists $foo6->foo->{foo2};
$foo6->delete_foo(qw/bar2 baz2/);
is_deeply($foo6->foo,{ 
	foo => 1,
	bar => undef,
	baz => 2,
});

is $foo6->accessor_foo('baz'),2;
$foo6->accessor_foo( 'qux' => 10 );
is $foo6->foo->{qux}, 10;
throws_ok{
	$foo6->accessor_foo(1,2,3);
} qr/^One or two arguments expected, not /;

my @keys = sort $foo6->keys_foo;
is_deeply(\@keys,[qw/bar baz foo qux/]);

my@values = $foo6->values_foo;
is scalar(@values), 4;

my @kv = $foo6->kv_foo;
is scalar(@values), 4;
ok List::MoreUtils::all { ref($_) eq 'ARRAY' } @kv;

my %elements = $foo6->elements_foo;
is_deeply(\%elements,{ foo => 1, bar => undef, baz => 2, qux => 10 });


$foo6->clear_foo;
is_deeply($foo6->foo, {} );

$foo6->set_foo2( foo => 'foo' );
is $foo6->foo2->{foo}, 'foo';
throws_ok{
	$foo6->set_foo2(bar => {});
} qr/Value HASH\(.*?\) did not pass container type constraint 'Str'/;

$foo6->access_foo2( 'bar' => 'bar' );
is $foo6->foo2->{bar}, 'bar';
throws_ok {
	$foo6->access_foo2( 'baz' => [] );
} qr/Value ARRAY\(.*?\) did not pass container type constraint 'Str'/;

ok $foo6->meta->get_attribute('foo3')->type_constraint->equals('HashRef');


# Code
{
	package Foo7;
	use Shaft;
	
	has 'foo' => (
		is => 'rw',
		isa => 'CodeRef',
		traits => ['Code'],
		handles => {
			call => 'execute',
			call_as_method => 'execute_method',
		},
	);

	has 'foo2' => (
		traits => ['Code'],
		handles => {},
	);
}

can_ok('Foo7',qw/call call_as_method/);

my $foo7 = Foo7->new( foo => sub{ return [@_] }, foo2 => sub{ return [@_] } );
is_deeply($foo7->call(qw/foo bar/),[qw/foo bar/]);
is_deeply($foo7->call_as_method(qw/foo bar/),[$foo7,qw/foo bar/]);

ok $foo7->meta->get_attribute('foo2')->type_constraint->equals('CodeRef');

# Test for error handling

throws_ok{
	package Bar1;
	use Shaft;
	has 'bar' => ( isa => 'Str', traits => ['Number'], handles => {} );
} qr/^The type constraint for .*? must be a subtype of /;

lives_ok {
	package Bar2;
	use Shaft;
	has 'bar' => ( traits => ['Number'] );
};

throws_ok {
	package Bar2;
	use Shaft;
	has 'bar' => ( traits => ['Number'], handles=> [] );
} qr/^The 'handles' option for attribute\(bar\) must be a HASH reference, not /;

throws_ok {
	package Bar3;
	use Shaft;
	has 'bar' => ( traits => ['Number'], handles=> { 'get_bar' => 'get' } );
} qr/^get is an unsupported method type/;

__END__
