package Shaft::MethodAttributes::Handler;
use strict;
use warnings;
use Shaft::Util ();

my $global_phase  = 0;
my @global_phases = qw/BEGIN CHECK INIT END/;
my %global_phases = (
	BEGIN => 0,
	CHECK => 1,
	INIT  => 2,
	END   => 3
);
my %handle_phase;

my $builtin = qr/lvalue|method|locked|unique|shared/;
my %symcache;
my @attrcache;

sub _find_symbol {
	my ( $class, $coderef ) = @_;
	return $symcache{ $class, $coderef } if $symcache{ $class, $coderef };
	no strict 'refs';
	for my $sym ( values %{ $class . "::" } ) {
		use strict;
		next unless ref( \$sym ) eq 'GLOB';
		return $symcache{ $class, $coderef } = \$sym
			if *{$sym}{CODE} && *{$sym}{CODE} == $coderef;
	}

}

sub _prepare_attribute_handler {
	no strict 'refs';
	for (@attrcache) {
		my ( $class, $ref ) = @{$_};
		my $symbol = _find_symbol( $class, $ref )
			|| die "Can't prepare attribute handler";
		my $name    = *{$symbol}{NAME};
		my $handler = "${class}::_ATTR_${name}_HANDLER";
		*$handler = $ref;
	}
	@attrcache = ();
}

sub _generate_code_attribute_handler {
	sub {
		_prepare_attribute_handler();
		my ( $class, $ref,  @attrs ) = @_;
		my ( undef,  $file, $line )  = caller(2);
		my $meta = $class->can('meta') ? $class->meta : undef;
		for (@attrs) {
			my ( $attr, $data ) = /^([a-z_]\w*)(?:[(](.*)[)])?$/is;
			if ( $attr eq 'METHOD_ATTR' ) {
				$data ||= 'CHECK';
				if ( $data =~ s/\s*,?\s*(BEGIN)\s*,?\s*// ) {
					$handle_phase{$ref}{BEGIN} = 1;
				}
				if ( $data =~ s/\s*,?\s*(CHECK)\s*,?\s*// ) {
					$handle_phase{$ref}{CHECK} = 1;
				}
				if ( $data =~ s/\s*,?\s*(INIT)\s*,?\s*// ) {
					$handle_phase{$ref}{INIT} = 1;
				}
				if ( $data =~ s/\s*,?\s*(END)\s*,?\s*// ) {
					$handle_phase{$ref}{END} = 1;
				}
				push @attrcache, [ $class, $ref ];
			}
			else {

				my $handler = $class->can("_ATTR_${attr}_HANDLER");

				if ( $handler || $meta ) {
					if ( defined($data) && $data ne q{} ) {
						my $evaled = eval("package $class;no strict;no warnings;local \$SIG{__WARN__}=Shaft::Exception->can('throw');[$data]");
						$data = $evaled unless $@;
					}
					else {
						$data = undef;
					}

					my $spec = Shaft::MethodAttributes::Spec->new(
						[   $class, $ref, $attr, $data,
							$handler ? $handle_phase{$handler} : {},
							$file, $line
						]
					);

					if ($handler) {
						for my $gphase (@global_phases) {
							if ( $global_phases{$gphase} <= $global_phase ) {
								apply_handler( $spec, $gphase );
							}
						}
					}
					if ($meta) {
						$meta->register_method_attributes($spec);
					}
				}
				else {
					next;
				}
			}
			$_ = undef;
		}
		return grep { defined && !/$builtin/ } @attrs;
	};
}

{
	my $handler = _generate_code_attribute_handler();
	no strict 'refs';
	*{"Shaft::MethodAttributes::UNIVERSAL::MODIFY_CODE_ATTRIBUTES"}
		= $handler;

	push @UNIVERSAL::ISA, 'Shaft::MethodAttributes::UNIVERSAL'
		unless grep /^Shaft::MethodAttributes::UNIVERSAL$/, @UNIVERSAL::ISA;
}

sub phase_handler {
	my $phase = shift;
	for my $meta ( grep { defined($_) && $_->isa('Shaft::Meta::Class') }
		Shaft::Util::get_all_metaclass_instances() )
	{
		my $class = $meta->name;
		for my $attrs ( $meta->get_method_attributes ) {
			apply_handler( $attrs, $phase );
		}
	}
	return 1;
}

sub apply_handler {
	my ( $spec, $phase ) = @_;
	_prepare_attribute_handler() if @attrcache && $phase eq 'CHECK';
	my ( $class, $ref, $attr, $data, $phase_map, $file, $line ) = @$spec;
	return unless $phase_map->{$phase};
	my $handler = "_ATTR_${attr}_HANDLER";
	my $symbol = _find_symbol( $class, $ref );
	$symbol ||= 'ANON';
	my $ref_from_glob = ref $symbol eq 'GLOB' ? *{$symbol}{CODE} : undef;
	$class->$handler( $symbol,
		$ref_from_glob ? $ref_from_glob : $ref,
		$attr, $data, $phase, $file, $line );
}

{
	no warnings 'void';

	CHECK {
		$global_phase++;
		phase_handler('CHECK');
	}

	INIT {
		$global_phase++;
		phase_handler('INIT');
	}
}

END {
	$global_phase++;
	phase_handler('END');
}

package Shaft::MethodAttributes::Spec;
use strict;
use warnings;

our $VERSION = '0.01';

sub new {
	my ( $class, $spec ) = @_;
	return bless $spec, $class;
}

sub package_name {
	shift->[0];
}

sub method_ref {
	shift->[1];
}

sub attribute_name {
	shift->[2];
}

sub attribute_args {
	shift->[3];
}

sub handle_phase_map {
	shift->[4];
}

sub filename {
	shift->[5];
}

sub line {
	shift->[6];
}

1;
__END__

=head1 NAME

Shaft::MethodAttributes::Handler

=head1 METHODS

=over 2

=item apply_handler

=item phase_handler

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
