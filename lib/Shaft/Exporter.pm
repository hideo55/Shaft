package Shaft::Exporter;
use strict;
use warnings;
use Sub::Name qw(subname);
use List::MoreUtils qw(uniq);
use Data::Util
	qw(:check get_code_info install_subroutine uninstall_subroutine);

my %EXPORT_SPEC;
our $CALLER;

sub _throw_error {
	require Shaft::Exception;
	goto &Shaft::Exception::throw;
}

sub import {
	my ( $class, %option ) = @_;
	strict->import;
	warnings->import;
	if ( exists( $option{-setup} ) ) {
		if ( ref( $option{-setup} ) eq 'HASH' ) {
			@_ = ( undef, %{ $option{-setup} } );
			goto &setup_import_methods;
		}
	}
}

sub setup_import_methods {
	my ( undef, %conf ) = @_;
	my $class = caller;

	$EXPORT_SPEC{$class} = \%conf;

	my @exports_from = _follow_exports_from($class);
	unshift @exports_from, $class;

	my ( $exports, $groups )
		= _make_exports_conf( \@exports_from );

	my @exports_name = keys %$exports;

	_check_and_rewrite_group_config( $groups, \@exports_name );

	unless ( _has_method( $class, 'import' ) ) {
		my $import = sub {
			strict->import;
			warnings->import;

			my $metaclass;
			my @traits;
			my @superclasses;
			my $prefix;
			my $suffix;

			_strip_commands(
				\@_,
				-metaclass   => \$metaclass,
				-traits      => \@traits,
				-extends     => \@superclasses,
				-with_prefix => \$prefix,
				-with_suffix => \$suffix,
			);

			$metaclass
				= Shaft::Util::resolve_metaclass_alias(
				'Class' => $metaclass )
				if defined $metaclass && length $metaclass;

			$CALLER = _get_caller(@_);

			my $did_init_meta;
			for my $c ( grep { $_->can('init_meta') } @exports_from ) {
				local $CALLER = $CALLER;
				$c->init_meta(
					for_class => $CALLER,
					metaclass => $metaclass
				);
				$did_init_meta = 1;
			}

			if (@superclasses) {
				if ( $did_init_meta
					&& !$CALLER->meta->isa('Shaft::Meta::Role') )
				{
					local $CALLER = $CALLER;
					$CALLER->meta->superclasses(@superclasses);
				}
				else {
					_throw_error $did_init_meta
						? "Role dose not support '-extends' command"
						: "Can't provide '-extends' when $class does not hove an init_meta() method";
				}
			}

			if (@traits) {
				if ($did_init_meta) {
					local $CALLER = $CALLER;
					_apply_meta_traits( $CALLER, \@traits );
				}
				else {
					_throw_error
						"Can't provide '-traits' when $class does not hove an init_meta() method";
				}
			}

			my @exports = @{ _expand_groups( $groups, @_ ) };

			for my $keyword (@exports) {
				if ( my $spec = $exports->{$keyword} ) {
					my $name = $keyword;
					$name
						= ( $prefix ? $prefix : '' ) 
						. $name
						. ( $suffix ? $suffix : '' );
					my $code
						= $spec->{lazy} ? $spec->{code}->() : $spec->{code};
					no strict 'refs';
					no warnings 'redefine';
					*{ $CALLER . '::' . $name } = $code;
				}
				else {
					_throw_error "The $class does not export '$keyword'";
				}
			}
		};
		install_subroutine( $class,
			import => subname( "${class}::import" => $import ) );

	}

	unless ( _has_method( $class, 'unimport' ) ) {
		if ( scalar(@exports_name) > 0 ) {
			my $unimport = sub {
				my $caller = caller;
				for (@exports_name) {
					uninstall_subroutine( $caller, $_ );
				}
			};
			install_subroutine( $class,
				unimport => subname( "${class}::unimport" => $unimport ) );
		}
	}
}

sub _make_exports_conf {
	my $exports_from = shift;

	my %exports;
	my %groups;

	for my $package (@$exports_from) {
		my $spec = $EXPORT_SPEC{$package};
		
		if ( $spec->{exports} && ref( $spec->{exports} ) eq 'ARRAY' ) {

			foreach my $name ( @{ $spec->{exports} } ) {
				my ( $code, $code_name, $code_package );
				if ( ref($name) eq 'CODE' ) {
					$code = $name;
					( $code_package, $code_name ) = get_code_info($code);
					$code = undef if $code_name eq '__ANON__';
				}
				else {
					$code
						= do { no strict 'refs'; \&{ $package . '::' . $name } };
					$code_package = $package;
					$code_name    = $name;
				}
				if ($code) {
					$exports{$code_name} = { code => $code };
				}
			}
		}

		if ( $spec->{with_meta} && ref( $spec->{with_meta} ) eq 'ARRAY' ) {
			foreach my $name ( @{ $spec->{with_meta} } ) {
				my ( $code, $fqname );
				$fqname         = $package . '::' . $name;
				$code           = do { no strict 'refs'; \&{$fqname} };
				$exports{$name} = {
					code => sub { _make_curry_with_meta( $fqname => $code ) },
					lazy => 1,
				};
			}
		}

		if ( $spec->{groups} && ref( $spec->{groups} ) eq 'HASH' ) {
			;
			%groups = ( %groups, %{ $spec->{groups} } );
		}
	}
	
	while( my ($key, $value) = each %groups ){
		( ref $value eq 'ARRAY' ) || _throw_error "The group value of '$key' must be ARRAY reference";
	}

	return ( \%exports, \%groups );
}

sub _make_curry_with_lazy_args {
	my ( $name, $code, $generator, @args ) = @_;
	my $curry = sub {
		my @curry = $generator->(@args);
		unshift @_, @curry;
		goto &$code;
	};
	if ( my $p = prototype($code) ) {
		&Scalar::Util::set_prototype( $curry, $p );
	}
	return subname $name, $curry;
}

sub _make_curry_with_meta {
	my ( $name, $code ) = @_;
	my $caller = $CALLER;
	return _make_curry_with_lazy_args( $name, $code,
		sub { Shaft::Util::class_of(shift) }, $caller );
}

{
	my $seen = {};

	sub _follow_exports_from {
		my $exporting_package = shift;

		local %$seen = ( $exporting_package => 1 );

		return uniq( _follow_exports_from_real($exporting_package) );
	}

	sub _follow_exports_from_real {
		my $exporting_package = shift;

		if ( !exists $EXPORT_SPEC{$exporting_package} ) {
			my $loaded = Shaft::Util::is_class_loaded($exporting_package);

			die
				"Package in exports_from ($exporting_package) does not seem to use Shaft::Exporter"
				. ( $loaded ? "" : " (is it loaded?)" );

		}

		my $exports_from = $EXPORT_SPEC{$exporting_package}{exports_from};

		return unless defined $exports_from;
		my @exports_from
			= ref $exports_from ? @{$exports_from} : ($exports_from);

		for my $package (@exports_from) {
			die
				"Circular reference in exports_from parameter to Shaft::Exporter between $exporting_package and $package"
				if $seen->{$package};

			$seen->{$package} = 1;
		}

		return @exports_from,
			map { _follow_exports_from_real($_) } @exports_from;
	}

}

sub _get_caller {
	my $offset = 1;

	return
		  ( ref $_[1] && defined $_[1]->{into} ) ? $_[1]->{into}
		: ( ref $_[1] && defined $_[1]->{into_level} )
		? caller( $offset + $_[1]->{into_level} )
		: caller($offset);
}

sub _strip_commands {
	my ( $args, %commands ) = @_;

	for ( my $i = 0; $i < @{$args}; $i++ ) {
		if ( my $slot_ref = $commands{ $args->[$i] } ) {
			my $arg = $args->[ $i + 1 ];
			splice @{$args}, $i, 2;

			if ( ref($slot_ref) eq 'ARRAY' ) {
				@{$slot_ref} = ref($arg) eq 'ARRAY' ? @{$arg} : $arg;
			}
			else {
				${$slot_ref} = $arg;
			}
			$i--;
		}
	}
}

sub _check_and_rewrite_group_config {
	my ( $conf, $exports ) = @_;
	unless ( defined( $conf->{default} ) ) {
		$conf->{default} = [':all'];
	}
	$conf->{all} = $exports;

}

sub _apply_meta_traits {
	my ( $class, $traits ) = @_;

	my $meta = $class->meta;

	my $type = ( split /::/, ref $meta )[-1]
		or _throw_error
		"Can't determine metaclass type for trait application. Meta isa "
		. ref $meta;

	my @resolved_traits = map {
		ref $_
			? $_
			: Shaft::Util::resolve_metatrait_alias( $type => $_ )
	} @$traits;

	require Shaft::Util::MetaRole;
	Shaft::Util::MetaRole::apply_metaclass_roles(
		for_class       => $class,
		metaclass_roles => \@resolved_traits
	);
}

sub _group_name {
	my ($name) = @_;

	return if ( index q{-:}, ( substr $name, 0, 1 ) ) == -1;
	return substr $name, 1;
}

sub _expand_groups {
	my ( $config, @args ) = @_;
	my %seen;

	my ( $class, @groups ) = @args;

	my @exports = _expand_group( $config, \@groups );

	if ( @exports == 0 ) {
		my @default = @{ $config->{default} };
		@exports = _expand_group( $config, \@default );
	}

	@exports = uniq @exports;

	return \@exports;
}

sub _expand_group {
	my ( $config, $groups ) = @_;
	my %seen;

	my @groups = @$groups;
	my @exports;
	for my $i ( reverse 0 .. $#groups ) {
		my $g = $groups[$i];
		next if ref $g;
		next if $seen{$g};
		$seen{$g}++;
		if ( my $group_name = _group_name($g) ) {
			if ( my $group = $config->{$group_name} ) {
				splice @groups, $i, 1;
				push @exports, @$group;
			}
			else {
				_throw_error "Can't export unknown group '$group_name'";
			}
		}
	}

	if ( @groups > 0 ) {
		push @exports, grep { !ref($_) } @groups;
	}

	return @exports;
}

sub _has_method {
	my ( $class, $name ) = @_;
	no strict 'refs';
	my $namespace = \%{$class . '::'};
	return 0 unless exists $namespace->{$name};
	my $symbol = \$namespace->{$name};
	return defined( *{$symbol}{CODE} );
}

1;
__END__

=head1 NAME

Shaft::Exporter - Function exporting utility for Shaft

=head1 METHODS

=over 4

=item setup_import_methods

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
