use strict;
use warnings;
use Test::More;
use Test::Exception;

{			
	package Foo::Role;
	use Shaft::Role;
	
	around hoge => sub {
		my ($next,$self) = @_;
		$self->foo('[BEFORE]');
		$self->$next;
		$self->foo( $self->foo . '[AFTER]' );
		return $self->foo;
	};
	
	package Foo;
	use Shaft;

	with 'Foo::Role';
	
	Public foo => ( is => 'rw' );
	
	sub hoge {
		$_[0]->foo($_[0]->foo . '[BODY]');
	}	
}

ok( Foo->new->hoge eq '[BEFORE][BODY][AFTER]');
isa_ok( Foo->meta->get_method('hoge'), 'Shaft::Meta::Method::Wrapped');
Foo->meta->remove_method('hoge');

done_testing;