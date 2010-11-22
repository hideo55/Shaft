use strict;
use warnings;
use Test::More;
use Test::Exception;
{			
	package Foo;
	use Shaft;
	
	Public foo => ( is => 'rw', default => q{} );
	
	sub hoge {
		$_[0]->foo($_[0]->foo . '[BODY]');
	}
	
	sub fuga2 {
		1;
	}
	
	sub piyo {
		1;
	}
	
	package Bar;
	use Shaft;
	extends 'Foo';
	
	override hoge => sub {
		my $self = shift;
		$self->foo( '[OVERRIDE]');
		super();
		$self->foo( $self->foo . '[OVERRIDE]');
	};
	
	sub fuga1 {
		super();
	}
	
	override fuga2 => sub {
		local $Shaft::SUPER_PACKAGE = 'Foo';
		super();
	};
	
	override piyo => sub {
		local $Shaft::SUPER_BODY = undef;
		super();
	};
	
}

ok( Foo->new->hoge eq '[BODY]' );
ok( Bar->new->hoge eq '[OVERRIDE][BODY][OVERRIDE]');
isa_ok( Bar->meta->get_method('hoge'),'Shaft::Meta::Method::Overridden');

is(Bar->fuga1, undef);
is(Bar->fuga2, undef);
is(Bar->piyo, undef);

Bar->meta->remove_method($_) for(qw/hoge fuga2 piyo/);

throws_ok{
	package Baz;
	use Shaft;
	
	override 'baz' => sub {
		super();
	};
} qr/^You cannot override 'baz' because it has no super method/;

throws_ok{
	package Qux;
	use Shaft;
	
	sub qux { 1 }
	
	override 'qux' => sub {
		super();
	};
} qr/^Can't add an override method if a local method is already present/;

done_testing;