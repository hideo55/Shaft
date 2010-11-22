package Shaft::Meta::Attribute::Native::MethodProvider::Array;
use Shaft::Role;
use List::Util;
use List::MoreUtils;

sub count : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure("
		sub { scalar \@{ \$_[0]->$reader() } }
	");
}

sub is_empty : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure("
		sub { scalar \@{ \$_[0]->$reader() } ? 0 : 1 }");
}

sub first : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub {
			my (\$instance, \$predicate) = \@_;
			List::Util::first { \$predicate->() } \@{ \$instance->$reader() };
		}",
	);
}

sub map : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub { CORE::map { \$_[1]->(\$_) } \@{ \$_[0]->$reader() } }");
}

sub reduce : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub { 
			my (\$instance, \$f) = \@_;
			our (\$a,\$b);
			List::Util::reduce { \$f->(\$a,\$b) } \@{ \$instance->$reader() };
		}",
	);
}

sub sort :method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub { 
			my ( \$instance, \$predicate ) = \@_;
			if( \$predicate ){
				die q{Argument must be a code reference}
					if ref \$predicate ne 'CODE';
				return CORE::sort { \$predicate->(\$a,\$b) } \@{ \$instance->$reader() };
			}
			else{
				return CORE::sort \@{ \$instance->$reader() };
			}
		}",
	);
}

sub shuffle : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub {
			my (\$instance) = \@_;
			List::Util::shuffle \@{ \$instance->$reader() };
		}",
	);
}

sub grep : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub { CORE::grep { \$_[1]->(\$_) } \@{ \$_[0]->$reader() } }");
}

sub uniq : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub {
			my (\$instance) = \@_;
			List::MoreUtils::uniq \@{ \$instance->$reader() };
		}",
	);
}

sub elements : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure("sub { \@{ \$_[0]->$reader() } }");
}

sub join : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub { CORE::join \$_[1], \@{ \$_[0]->$reader() } }");
}

sub push : method {
	my ( $attr, $reader ) = @_;
    
	if( $attr->type_constraint->is_parameterized ){
		my $container_type_constraint = $attr->type_constraint->type_parameter;
		
		return $attr->make_eval_closure(
			"sub {
				my \$self = CORE::shift;
				( \$attr->type_constraint->type_parameter->check(\$_) ) || throw_error(qq{Value } . ( \$_ || 'undef' ) . qq{ did not pass container type constraint '$container_type_constraint'}) foreach \@_;
				CORE::push \@{ \$self->$reader() } => \@_ 
			}"
		);
	}
	else{
		return $attr->make_eval_closure(
			"sub {
				my \$self = CORE::shift;
				CORE::push \@{ \$self->$reader() } => \@_ }"
		);
	}
}

sub pop : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure("sub { CORE::pop \@{ \$_[0]->$reader() } }");
}

sub unshift : method {
	my ( $attr, $reader ) = @_;
	if( $attr->type_constraint->is_parameterized ){
		my $container_type_constraint = $attr->type_constraint->type_parameter;
		return $attr->make_eval_closure(
			"sub {
				my \$self = CORE::shift; 
				( \$attr->type_constraint->type_parameter->check(\$_) ) || throw_error( qq{Value } . ( \$_ || 'undef' ) . qq{ did not pass container type constraint '$container_type_constraint'}) foreach \@_;
				CORE::unshift \@{ \$self->$reader() } => \@_ 
			}"
		);
	}else{
		return $attr->make_eval_closure("sub {
				my \$self = CORE::shift; 
				CORE::unshift \@{ \$self->$reader() } => \@_ }
		");
	}
}

sub shift : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure("sub { CORE::shift \@{ \$_[0]->$reader() } }");
}

sub get : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure("
		sub { \$_[0]->$reader()->[ \$_[1] ] }"
	);
}

sub set : method {
	my ( $attr, $reader ) = @_;
	if( $attr->type_constraint->is_parameterized ){
		my $container_type_constraint = $attr->type_constraint->type_parameter;
		return $attr->make_eval_closure("sub { 
			( \$attr->type_constraint->type_parameter->check(\$_[2]) ) || throw_error(qq{Value } . ( \$_[2] || 'undef' ) . qq{ did not pass container type constraint '$container_type_constraint'});
			\$_[0]->$reader()->[ \$_[1] ] = \$_[2];
		}");
	}else{
		return $attr->make_eval_closure(
			"sub { \$_[0]->$reader()->[ \$_[1] ] = \$_[2] }");
	}
}

sub accessor : method {
    my ( $attr, $reader, $writer ) = @_;

	if( $attr->type_constraint->is_parameterized ){
		my $container_type_constraint = $attr->type_constraint->type_parameter;
        return $attr->make_eval_closure("sub {
            my \$self = CORE::shift;
            if ( \@_ == 1 ) {    # reader
                return \$self->$reader()->[ \$_[0] ];
            }
            elsif ( \@_ == 2 ) {    # writer
                ( \$attr->type_constraint->type_parameter->check( \$_[1] ) )
                  || throw_error(qq{Value }
                  . ( \$_[1] || 'undef' )
                  . qq{ did not pass container type constraint '$container_type_constraint'});
                \$self->$reader()->[ \$_[0] ] = \$_[1];
            }
            else {
                throw_error(qq{One or two arguments expected, not } . \@_);
            }
        }");
    }
    else {
        return $attr->make_eval_closure("sub {
            my \$self = CORE::shift;
            if ( \@_ == 1 ) {    # reader
                return \$self->$reader()->[ \$_[0] ];
            }
            elsif ( \@_ == 2 ) {    # writer
                \$self->$reader()->[ \$_[0] ] = \$_[1];
            }
            else {
                throw_error(qq{One or two arguments expected, not } . \@_);
            }
        }");
    }
}

sub clear : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure("sub { \@{ \$_[0]->$reader() } = () }");
}

sub delete : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub { CORE::splice \@{ \$_[0]->$reader() }, \$_[1], 1 }");
}

sub insert : method {
	my ( $attr, $reader ) = @_;

	if( $attr->type_constraint->is_parameterized ){
		my $container_type_constraint = $attr->type_constraint->type_parameter;
		return $attr->make_eval_closure("sub {
			( \$attr->type_constraint->type_parameter->check(\$_[2]) ) || throw_error(qq{Value } . ( \$_[2] || 'undef' ) . qq{ did not pass container type constraint '$container_type_constraint'});
			CORE::splice \@{ \$_[0]->$reader() }, \$_[1], 0, \$_[2];
		}");
	}
	else{
		return $attr->make_eval_closure(
			"sub { CORE::splice \@{ \$_[0]->$reader() }, \$_[1], 0, \$_[2] }");
	}
}

sub splice : method {
	my ( $attr, $reader ) = @_;
	if( $attr->type_constraint->is_parameterized ){
		my $container_type_constraint = $attr->type_constraint->type_parameter;
		return $attr->make_eval_closure(
			"sub {
				my ( \$self, \$offset, \$length, \@args ) = \@_;
				( \$attr->type_constraint->type_parameter->check(\$_) ) || throw_error( qq{Value } . ( \$_ || 'undef' ) . qq{ did not pass container type constraint '$container_type_constraint'}) foreach \@args;
				CORE::splice \@{ \$self->$reader() }, \$offset, \$length, \@args;
			}"
		);
	}
	else{
		return $attr->make_eval_closure(
			"sub {
				my ( \$self, \$offset, \$length, \@args ) = \@_;
				CORE::splice \@{ \$self->$reader() }, \$offset, \$length, \@args;
			}"
		);
	}
}

sub sort_in_place :method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub { 
			my ( \$instance, \$predicate ) = \@_;
			my \@sorted;
			if( \$predicate ){
				die q{Argument must be a code reference}
					if ref \$predicate ne 'CODE';
				\@sorted = CORE::sort { \$predicate->(\$a,\$b) } \@{ \$instance->$reader() };
			}
			else{
				\@sorted = CORE::sort \@{ \$instance->$reader() };
			}
			\$instance->$writer(\\\@sorted);
		}",
	);
}

sub natatime : method {
	my ( $attr, $reader ) = @_;
	return $attr->make_eval_closure(
		"sub {
			my (\$instance, \$n, \$f) = \@_;
			my \$it = List::MoreUtils::natatime(\$n,\@{ \$instance->$reader() });
			return \$it unless\$it;
			while( my \@vals = \$it->() ){
				\$f->(\@vals);
			}
		}",
	);
}

no Shaft::Role;
1;
__END__


=pod

=head1 NAME

Shaft::Meta::Attribute::Native::MethodProvider::Array

=head1 PROVIDE METHODS

=over 4

=item count

=item is_empty

=item elements

=item get($index)

=item pop

=item push($value1, $value2, ...)

=item shift

=item unshift($value1, $value2, ...)

=item splice($offset,$length,@values)

=item first(sub{...})

=item grep(sub{...})

=item map(sub{...})

=item reduce(sub{...})

=item sort(sub{...})

=item sort_in_place(sub{...})

=item shuffle

=item uniq

=item join($str)

=item set($index,$value)

=item delete($index);

=item insert($index,$value);

=item clear

=item accessor

=item natatime($n,$code)

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut