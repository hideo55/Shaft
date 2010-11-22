use strict;
use warnings;
use Test::More;
use Test::Exception;

{			
	package Foo;
	use Shaft;
	
	Public foo => ( is => 'rw' );
	
	sub hoge {
		$_[0]->foo($_[0]->foo . '[BODY]');
	}
	
	around hoge => sub {
		my ($next,$self) = @_;
		$self->foo('[BEFORE]');
		$self->$next;
		$self->foo( $self->foo . '[AFTER]' );
		return $self->foo;
	};
	
}

ok( Foo->new->hoge eq '[BEFORE][BODY][AFTER]');
isa_ok( Foo->meta->get_method('hoge'), 'Shaft::Meta::Method::Wrapped');
Foo->meta->remove_method('hoge');

throws_ok{
	package Bar;
	use Shaft;
	
	sub hoge { 1 }
	
	around sub{ 1 };
	
} qr/^You must pass in a method name/;

done_testing;