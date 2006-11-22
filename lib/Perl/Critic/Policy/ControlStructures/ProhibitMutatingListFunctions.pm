##############################################################################
#      $URL$
#     $Date$
#   $Author$
# $Revision$
##############################################################################

package Perl::Critic::Policy::ControlStructures::ProhibitMutatingListFunctions;

use strict;
use warnings;
use Perl::Critic::Utils;
use List::MoreUtils qw( none any );
use base 'Perl::Critic::Policy';

our $VERSION = 0.22;

my @builtin_list_funcs = qw( map grep );
my @cpan_list_funcs    = qw( List::Util::first ),
  map { 'List::MoreUtils::'.$_ } qw(any all none notall true false firstidx first_index
                                    lastidx last_index insert_after insert_after_string);




#-----------------------------------------------------------------------------

sub _is_topic {
    my $elem = shift;
    return defined $elem
        && $elem->isa('PPI::Token::Magic')
            && $elem eq q{$_}; ##no critic (InterpolationOfMetachars)
}


#-----------------------------------------------------------------------------

my $desc = q{Don't modify $_ in list functions};  ##no critic (InterpolationOfMetachars)
my $expl = [ 114 ];

#----------------------------------------------------------------------------

sub default_severity { return $SEVERITY_HIGHEST  }
sub default_themes   { return qw(danger pbp)     }
sub applies_to       { return 'PPI::Token::Word' }

#----------------------------------------------------------------------------

sub new {
    my ( $class, %config ) = @_;
    my $self = bless {}, $class;

    my @list_funcs = $config{list_funcs}
        ? $config{list_funcs} =~ m/(\S+)/gxms
        : ( @builtin_list_funcs, @cpan_list_funcs );

    if ( $config{add_list_funcs} ) {
        push @list_funcs, $config{add_list_funcs} =~ m/(\S+)/gxms;
    }

    # Hashify also removes duplicates!
    $self->{_list_funcs} = { hashify @list_funcs };

    return $self;
}

#----------------------------------------------------------------------------

sub violates {
    my ($self, $elem, $doc) = @_;

    # Is this element a list function?
    return if not $self->{_list_funcs}->{$elem};
    return if not is_function_call($elem);

    # Only the block form of list functions can be analyzed.
    return if not my $first_arg = first_arg( $elem );
    return if not $first_arg->isa('PPI::Structure::Block');
    return if not _has_topic_side_effect( $first_arg );

    # Must be a violation
    return $self->violation( $desc, $expl, $elem );
}

#----------------------------------------------------------------------------

sub _has_topic_side_effect {
    my $node = shift;

    # Search through all significant elements in the block,
    # testing each element to see if it mutates the topic.
    my $tokens = $node->find( 'PPI::Token' ) || [];
    for my $elem ( @{ $tokens } ) {
        next if not $elem->significant();
        return 1 if _is_assignment_to_topic( $elem );
        return 1 if _is_topic_mutating_regex( $elem );
        return 1 if _is_topic_mutating_func( $elem );
        return 1 if _is_topic_mutating_substr( $elem );
    }
    return;
}

#----------------------------------------------------------------------------

sub _is_assignment_to_topic {
    my $elem = shift;
    return if not _is_topic( $elem );

    my $sib = $elem->snext_sibling();
    if ($sib && $sib->isa('PPI::Token::Operator')) {
        return 1 if _is_assignment_operator( $sib );
    }

    my $psib = $elem->sprevious_sibling();
    if ($psib && $psib->isa('PPI::Token::Operator')) {
        return 1 if _is_increment_operator( $psib );
    }

    return;
}

#-----------------------------------------------------------------------------

sub _is_topic_mutating_regex {
    my $elem = shift;
    return if ! ( $elem->isa('PPI::Token::Regexp::Substitute')
                  || $elem->isa('PPI::Token::Regexp::Transliterate') );

    # If the previous sibling does not exist, then
    # the regex implicitly binds to $_
    my $prevsib = $elem->sprevious_sibling;
    return 1 if not $prevsib;

    # If the previous sibling does exist, then it
    # should be a binding operator.
    return 1 if not _is_binding_operator( $prevsib );

    # Check if the sibling before the biding operator
    # is explicitly set to $_
    my $bound_to = $prevsib->sprevious_sibling;
    return _is_topic( $bound_to );
}

#-----------------------------------------------------------------------------

sub _is_topic_mutating_func {
    my $elem = shift;
    return if not $elem->isa('PPI::Token::Word');
    return if not any { $elem eq $_ } qw(chop chomp undef);
    return if not is_function_call( $elem );

    # If these functions have no argument,
    # they default to mutating $_
    my $first_arg = first_arg( $elem );
    return 1 if not defined $first_arg;
    return _is_topic( $first_arg );
}

#-----------------------------------------------------------------------------

sub _is_topic_mutating_substr {
    my $elem = shift;
    return if $elem ne 'substr';
    return if not is_function_call( $elem );

    # 4-argument form of substr mutates its first arg,
    # so check and see if the first arg is $_
    my @args = parse_arg_list( $elem );
    return @args >= 4 && _is_topic( $args[0]->[0] );
}

#-----------------------------------------------------------------------------

my %assignment_ops = hashify qw( = *= /= += -= %= **= x= .= &= |= ^=  &&= ||= ++ -- );
sub _is_assignment_operator { return exists $assignment_ops{$_[0]} }

my %increment_ops = hashify qw( ++ -- );
sub _is_increment_operator { return exists $increment_ops{$_[0]} }

my %binding_ops = hashify qw( =~ !~ );
sub _is_binding_operator { return exists $binding_ops{$_[0]} }

1;

#----------------------------------------------------------------------------

__END__

=pod

=head1 NAME

Perl::Critic::Policy::ControlStructures::ProhibitMutatingListFunctions

=head1 DESCRIPTION

C<map>, C<grep> and other list operators are intended to transform arrays into
other arrays by applying code to the array elements one by one.  For speed,
the elements are referenced via a C<$_> alias rather than copying them.  As a
consequence, if the code block of the C<map> or C<grep> modify C<$_> in any
way, then it is actually modifying the source array.  This IS technically
allowed, but those side effects can be quite surprising, especially when the
array being passed is C<@_> or perhaps C<values(%ENV)>!  Instead authors
should restrict in-place array modification to C<for(@array) { ... }>
constructs instead, or use C<List::MoreUtils::apply()>.

=head1 CONSTRUCTOR

By default, this policy applies to the following list functions:

  map grep
  List::Util qw(first)
  List::MoreUtils qw(any all none notall true false firstidx first_index
                     lastidx last_index insert_after insert_after_string)

This list can be overridden the F<.perlcriticrc> file like this:

 [ControlStructures::ProhibitMutatingListFunctions]
 list_funcs = map grep List::Util::first

Or, one can just append to the list like so:

 [ControlStructures::ProhibitMutatingListFunctions]
 add_list_funcs = Foo::Bar::listmunge

=head1 LIMITATIONS

This policy deliberately does not apply to C<for (@array) { ... }> or
C<List::MoreUtils::apply()>.

Currently, the policy only detects explicit external module usage like this:

  my @out = List::MoreUtils::any {s/^foo//} @in;

and not like this:

  use List::MoreUtils qw(any);
  my @out = any {s/^foo//} @in;

This policy looks only for modifications of C<$_>.  Other naughtiness could
include modifying C<$a> and C<$b> in C<sort> and the like.  That's beyond the
scope of this policy.

=head1 AUTHOR

Chris Dolan <cdolan@cpan.org>

Michael Wolf <MichaelRWolf@att.net>

=head1 COPYRIGHT

Copyright (C) 2006 Chris Dolan.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 78
#   indent-tabs-mode: nil
# End:
# ex: set ts=8 sts=4 sw=4 expandtab :

