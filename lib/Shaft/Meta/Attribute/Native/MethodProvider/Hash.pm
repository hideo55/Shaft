package Shaft::Meta::Attribute::Native::MethodProvider::Hash;
use Shaft::Role;

sub exists : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub { CORE::exists \$_[0]->$reader()->{\$_[1]} ? 1 : 0 }");
}

sub defined : method {
	my ($attr, $reader) = @_;
	return $attr->make_eval_closure("sub{ 
		CORE::defined \$_[0]->$reader()->{ \$_[1] } ? 1 : 0;
	}");
}

sub keys : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure("sub { CORE::keys \%{ \$_[0]->$reader() } }");
}

sub values : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure("sub { CORE::values \%{ \$_[0]->$reader() } }");
}

sub kv : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
	"sub {
		my \$h = \$_[0]->$reader();
		map { [ \$_, \$h->{\$_} ] } CORE::keys \%\$h;
	}");
}

sub elements : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure("sub {
		my \$h = \$_[0]->$reader();
		map { \$_, \$h->{\$_} } CORE::keys \%\$h;
	}");
}

sub count : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub { scalar CORE::keys \%{ \$_[0]->$reader() } }");
}

sub is_empty : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub { scalar CORE::keys \%{ \$_[0]->$reader() } ? 0 : 1 }");
}

sub get : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure("sub { 
		my \$self = shift;
		return \@_ == 1 ? \$self->$reader()->{\$_[0]} : \@{ \$self->$reader() }{\@_} }"
	);
}

sub set : method {
	my ( $attr, $reader ) = @_;
	
	if( $attr->type_constraint->is_parameterized ){
		my $container_type_constraint = $attr->type_constraint->type_parameter;
		
		return $attr->make_eval_closure(
			"sub {
				my ( \$self, \@kvp ) = \@_;
				my ( \@keys, \@values );
				while (\@kvp) {
                	my ( \$key, \$value ) = ( shift(\@kvp), shift(\@kvp) );
                	( \$attr->type_constraint->type_parameter->check(\$value) )
                    || throw_error(qq{Value }
                    . ( \$value || 'undef' )
                    . qq{ did not pass container type constraint '$container_type_constraint'});
                	push \@keys,   \$key;
                	push \@values, \$value;
            	}
	            if ( \@values > 1 ) {
					\@{ \$self->$reader() }{\@keys} = \@values;
				}
				else {
					\$self->$reader()->{ \$keys[0] } = \$values[0];
				}
            }"
		);
	}
	else{
		return $attr->make_eval_closure(
			"sub {
				if (\@_ == 3) {
					\$_[0]->$reader()->{\$_[1]} = \$_[2];
				}
				else {
					my \$self = CORE::shift;
					my (\@k, \@v);
	 				while (\@_) {
						push \@k, shift;
						push \@v, shift;
					}
					\@{ \$self->$reader() }{\@k} = \@v;
				}
			}"
		);
	}
}

sub accessor : method {
    my ( $attr, $reader, $writer ) = @_;
    
	if( $attr->type_constraint->is_parameterized ){
		my $container_type_constraint = $attr->type_constraint->type_parameter;
		
		return $attr->make_eval_closure("sub {
            my \$self = shift;

            if ( \@_ == 1 ) {    # reader
                return \$self->$reader()->{ \$_[0] };
            }
            elsif ( \@_ == 2 ) {    # writer
                ( \$attr->type_constraint->type_parameter->check( \$_[1] ) )
                    || throw_error(qq{Value }
                    . ( \$_[1] || 'undef' )
                    . qq{ did not pass container type constraint '$container_type_constraint'});
                \$self->$reader()->{ \$_[0] } = \$_[1];
            }
            else {
                throw_error(qq{One or two arguments expected, not } . \@_);
            }
        }");
    }
    else {
        return $attr->make_eval_closure("sub {
            my \$self = shift;

            if ( \@_ == 1 ) {    # reader
                return \$self->$reader()->{ \$_[0] };
            }
            elsif ( \@_ == 2 ) {    # writer
                \$self->$reader()->{ \$_[0] } = \$_[1];
            }
            else {
                throw_error(qq{One or two arguments expected, not } . \@_);
            }
        }");
    }
}

sub clear : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure("sub { \%{ \$_[0]->$reader() } = () }");
}

sub delete : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub { CORE::delete \@{ shift->$reader() }{\@_} }");
}

no Shaft::Role;
1;
__END__

=pod

=head1 NAME

Shaft::Meta::Attribute::Native::MethodProvider::Hash

=head1 PROVIDE METHODS

=over 4

=item get($key,$key2,$key3...)

=item set($key => $value, $key2 => $value2...)

=item delete($key,$key2,$key3...)

=item keys

=item exists($key)

=item defined($key)

=item values

=item kv

=item elements

=item clear

=item count

=item is_empty

=item accessor

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut