use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::Exception;
use Test::Warn;
use List::MoreUtils qw(all any);
{

	package Foo;
	use Shaft;

	sub foo1 : Foo1 Foo2(1,2,3) Foo3 {
		1;
	}

	sub foo2 : Foo1 Foo3 {
		1;
	}

	sub foo3 : Foo2 {
		1;
	}

	sub foo4 { 1 }

	package Bar;
	use Shaft;

	sub bar1 : Foo1() {
		1;
	}
	
}

my $meta = Foo->meta;

my @attrs = $meta->get_method_attributes_by_method('foo1');
ok scalar(@attrs) == 3;
ok all { $_->isa('Shaft::MethodAttributes::Spec') } @attrs;
my ($attr) = grep { $_->attribute_name =~ /^Foo1$/ } @attrs;
ok $attr;
can_ok( $attr,
	qw/package_name attribute_name method_ref attribute_args handle_phase_map filename line/
);
is $attr->package_name,   'Foo';
is $attr->attribute_name, 'Foo1';
is $attr->method_ref,     $meta->get_method_body('foo1');
is $attr->attribute_args, undef;
ok ref( $attr->handle_phase_map ) eq 'HASH';
ok keys( %{ $attr->handle_phase_map } ) == 0;
is $attr->filename, __FILE__;
is $attr->line,     17;

$attr = ( Bar->meta->get_method_attributes_by_method('bar1') )[0];
is $attr->package_name,   'Bar';
is $attr->attribute_name, 'Foo1';

($attr) = grep { $_->attribute_name =~ /^Foo2$/ } @attrs;
is_deeply( $attr->attribute_args, [ 1, 2, 3 ] );

my @methods = $meta->get_methods_by_method_attribute_name('Foo1');
ok scalar(@methods) == 2;
ok $methods[0] == $meta->get_method_body('foo1')
	|| $methods[0] == $meta->get_method_body('foo2');

@attrs = $meta->get_method_attributes;
ok scalar(@attrs) == 6;
ok all { $_->isa('Shaft::MethodAttributes::Spec') } @attrs;

@attrs = $meta->get_method_attributes_by_method('foo4');
is scalar(@attrs), 0;

@attrs = $meta->get_method_attributes_by_method('foo5');
is scalar(@attrs), 0;

@attrs = $meta->get_method_attributes_by_methodref($meta->get_method_body('foo1'));
is scalar(@attrs), 3;
is $meta->get_method_attributes_by_methodref(), undef;
@attrs =$meta->get_method_attributes_by_methodref($meta->get_method_body('foo4'));
is scalar(@attrs), 0;

{

	package Baz;
	use Shaft;
	no strict;
	no warnings;

	BEGIN{
		${Baz::}{a} = undef;
	}

	our @ARGS;

	sub Hoge : METHOD_ATTR(BEGIN,INIT,END) {
		push @ARGS, [@_];
	}

	sub Fuga : METHOD_ATTR(CHECK) {
		1;
	}

	package Qux;
	use Shaft -extends => 'Baz';

	sub qux1 : Hoge {
		1;
	}

	sub qux2 : Fuga {
		1;
	}

	my $code = sub : Hoge {
		1;
	};
}


$meta = Qux->meta;
$attr = ( $meta->get_method_attributes_by_method('qux1') )[0];
can_ok 'Baz', '_ATTR_Hoge_HANDLER';
is_deeply( $attr->handle_phase_map,
	{ BEGIN => 1, INIT => 1, END => 1 } );

$attr = ( $meta->get_method_attributes_by_method('qux2') )[0];
can_ok 'Baz', '_ATTR_Fuga_HANDLER';
is_deeply( $attr->handle_phase_map,
	{ CHECK => 1 } );

require MethodAttributeLazy;
$meta = MethodAttributeLazy->meta;
$attr = ( $meta->get_method_attributes_by_method('foo') )[0];
ok $attr;
is $attr->attribute_name, 'Foo';

{
	package Hoge;
	use Shaft;
	
	sub hoge : hoge_attr(aa\aa) {
		1;
	}

}

$attr = ( Hoge->meta->get_method_attributes_by_method('hoge') )[0];
ok $attr;
ok $attr->attribute_args, undef;

lives_ok {
	package Hoge2;
	use Shaft::MethodAttributes;

	sub hoge1 : method { 1 }
	
	sub hoge2 : lvalue { 
		my $value = shift;
	}

	sub hoge3 : locked { 1 }

	sub HogeATTR : METHOD_ATTR {
		1;
	}

	sub hoge4 : HogeATTR {
		1;
	}
};


throws_ok{
	Shaft::Util::load_class('MethodAttributeError1');
} qr/^Could not load class \(MethodAttributeError1\) because : Invalid CODE attribute/;


throws_ok {
	Shaft::Util::load_class('MethodAttributeError2');
} qr/^Could not load class \(MethodAttributeError2\) because : Can't prepare attribute handler/;


done_testing;
