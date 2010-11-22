#!/usr/bin/perl

use strict;
use warnings;
no warnings 'once'; # work around 5.6.2

{
	package Foo::Parent;
	use Shaft;
	
	sub foo { 1 }
	
	package Foo2;
	use Shaft;
	
	sub foo2 { 1 }
	
	package Foo::Role;
	use Shaft::Role;
	
    package Foo;
    use Shaft;
    extends 'Foo::Parent';
    
    has 'attr' => ( is => 'ro', isa => 'Foo2', default => sub{ Foo2->new }, handles => [qw/foo2/] );
    
    before 'foo' => sub{
    	1;
    };

    sub DEMOLISH {
        my $self = shift;
        my ($igd) = @_;

        print $igd || 0, "\n";
    }
}

{
    package Bar;
    use Shaft;

    sub DEMOLISH {
        my $self = shift;
        my ($igd) = @_;

        print $igd || 0, "\n";
    }

    __PACKAGE__->meta->make_immutable;
}

our $foo = Foo->new;
our $bar = Bar->new;
