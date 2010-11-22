use strict;
use warnings;

use Test::More tests => 6;

our @demolished;
{
	package Foo;
	use Shaft;

	sub DEMOLISH {
		my $self = shift;
		push @::demolished, __PACKAGE__;
	}

	package Foo::Sub;
	use Shaft;
	extends 'Foo';

	sub DEMOLISH {
		my $self = shift;
		push @::demolished, __PACKAGE__;
	}

	package Foo::Sub::Sub;
	use Shaft;
	extends 'Foo::Sub';

	sub DEMOLISH {
		my $self = shift;
		push @::demolished, __PACKAGE__;
	}
}

package main;
{
	my $foo = Foo->new;
}
is_deeply(\@demolished,['Foo']);
@demolished = ();
{
	my $foo_sub = Foo::Sub->new;
}
is_deeply(\@demolished,[qw/Foo::Sub Foo/]);
@demolished = ();
{
	my $foo_sub_sub = Foo::Sub::Sub->new;
}
is_deeply(\@demolished,[qw/Foo::Sub::Sub Foo::Sub Foo/]);
@demolished = ();

Foo->meta->make_immutable;
Foo::Sub->meta->make_immutable;
Foo::Sub::Sub->meta->make_immutable;
{
	my $foo = Foo->new;
}
is_deeply(\@demolished,['Foo']);
@demolished = ();
{
	my $foo_sub = Foo::Sub->new;
}
is_deeply(\@demolished,[qw/Foo::Sub Foo/]);
@demolished = ();
{
	my $foo_sub_sub = Foo::Sub::Sub->new;
}
is_deeply(\@demolished,[qw/Foo::Sub::Sub Foo::Sub Foo/]);
@demolished = ();

__END__