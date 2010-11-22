use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;

	has 'foo' => ( is => 'ro', isa => 'Int', default => 2 );

	sub AUTOMETHOD {
		my ($self) = @_;
		my $method = $_;
		my $val;
		if( $method=~ /^x(\d+)$/){
			$val = $1;
		}
		else{
			return;
		}
		return sub{
			return $self->foo * $val;
		};
	}

}

my $foo = Foo->new;

can_ok $foo,'x2';
is $foo->x2, 4;
can_ok $foo, 'x10';
is $foo->x10,20;
ok !$foo->can('method');
throws_ok { $foo->method } qr/^Can't locate object method method via Foo/;

our @pkg;

{
	package Bar;
	use Shaft;
	
	sub AUTOMETHOD{
		my ($class) = @_;
		my $method = $_;
		sub{
			push @::pkg, "${class}::${method}";
		}
	}
}

Bar->bar1;
Bar->bar2;

is_deeply(\@pkg, [qw/Bar::bar1 Bar::bar2/]);

done_testing;