use Test::More tests => 6;
{
	package Foo;
	use Shaft;
	
	has foo => ( is => 'rw' );
	
}

my $foo = Foo->new;
$foo->foo(1);
ok $foo->_dump;

my $data = $foo->_serialize;
ok $data;
my $foo2 = Foo->new;
$foo2->_deserialize($data);
is $foo2->foo, 1;

is $foo->_deserialize, undef;
is $foo->_deserialize(''), undef;
$data = Storable::nfreeze([]);
is $foo->_deserialize($data), undef;

__END__