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
	
	sub fuga {
		1;
	}
	
	package Bar::Role;
	use Shaft::Role;
	
	override hoge => sub {
		my $self = shift;
		$self->foo( '[OVERRIDE]');
		super();
		$self->foo( $self->foo . '[OVERRIDE]');
	};
	
	override fuga => sub {
		local $Shaft::SUPER_BODY = undef;
		super();
	};
	
	package Bar;
	use Shaft;	
	extends 'Foo';
	with 'Bar::Role';	
}

ok( Bar->new->hoge eq '[OVERRIDE][BODY][OVERRIDE]');
isa_ok( Bar->meta->get_method('hoge'),'Shaft::Meta::Method::Overridden');
ok( Bar::Role->meta->has_override_method_modifier('hoge') );
ok( Bar::Role->meta->has_override_method_modifier('fuga') );

is(Bar->fuga, undef);

Bar->meta->remove_method($_) for(qw/hoge fuga/);

throws_ok{
	package Baz::Role;
	use Shaft::Role;
	
	override 'baz' => sub {
		super();
	};
	
	sub baz { 1 }

} qr/^Can't add an override of method 'baz' because there is a local version of 'baz'/;

throws_ok {
	package Qux::Role1;
	use Shaft::Role;

	override 'qux' => sub { super() };

	package Qux::Role2;
	use Shaft::Role;

	override 'qux' => sub { super() };

	package Qux;
	use Shaft;
	
	with qw(Qux::Role1 Qux::Role2);
	
} qr/^We have encountered an 'override' method conflict with 'qux' during composition \(Two 'override' methods of the same name encountered\). This is fatal error./;

{
	package Quxx::Role1;
	use Shaft::Role;

	override 'quxx' => sub {
		super() + 1;
	};

	package Quxx::Role2;
	use Shaft::Role;

	package Quxx::Parent;
	use Shaft;

	sub quxx { 1 }

	package Quxx;
	use Shaft;
	extends 'Quxx::Parent';
	with qw(Quxx::Role1 Quxx::Role2);

}

my ($role) = Quxx->meta->roles;
ok !$role->has_override_method_modifier;
ok(Quxx::quxx() == 2);
Quxx->meta->remove_method('quxx');

my $code = sub { 2 };
lives_ok {
	package A::Role;
	use Shaft::Role;
	
	override 'foo' => $code;

	no Shaft::Role;

	package B::Role;
	use Shaft::Role;

	override 'foo' => $code;

	no Shaft::Role;

	package Hoge;
	use Shaft;

	sub foo { 1 };

	package Fuga;
	use Shaft;
	extends 'Hoge';
	with qw(A::Role B::Role);
};
ok(Fuga::foo() == 2);
Fuga->meta->remove_method('foo');

done_testing;