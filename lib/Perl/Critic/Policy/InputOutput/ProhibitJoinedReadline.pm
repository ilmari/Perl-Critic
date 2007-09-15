##############################################################################
#      $URL$
#     $Date$
#   $Author$
# $Revision$
##############################################################################

package Perl::Critic::Policy::InputOutput::ProhibitJoinedReadline;

use strict;
use warnings;
use Readonly;
use List::MoreUtils qw(any);

use Perl::Critic::Utils qw{ :severities :classification parse_arg_list };
use base 'Perl::Critic::Policy';

our $VERSION = 1.077;

#-----------------------------------------------------------------------------

Readonly::Scalar my $DESC => q{Use "local $/ = undef" or File::Slurp instead of joined readline}; ##no critic qw(Interpolation)
Readonly::Scalar my $EXPL => [213];

#-----------------------------------------------------------------------------

sub supported_parameters { return ()                     }
sub default_severity     { return $SEVERITY_MEDIUM       }
sub default_themes       { return qw( core pbp performance ) }
sub applies_to           { return 'PPI::Token::Word'     }

#-----------------------------------------------------------------------------

sub violates {
    my ( $self, $elem, undef ) = @_;

    return if $elem ne 'join';
    return if ! is_function_call($elem);
    my @args = parse_arg_list($elem);
    shift @args; # ignore separator string

    if (any { any { $_->isa('PPI::Token::QuoteLike::Readline') } @{$_} } @args) {
       return $self->violation( $DESC, $EXPL, $elem );
    }

    return;  # OK
}


1;

__END__

#-----------------------------------------------------------------------------

=pod

=head1 NAME

Perl::Critic::Policy::InputOutput::ProhibitJoinedReadline

=head1 DESCRIPTION

It's really easy to slurp a whole filehandle in at once with C<join
q{}, <$fh>>, but that's inefficient -- Perl goes to the trouble of
splitting the file into lines only to have that work thrown away.

To save performance, either slurp the filehandle without splitting like so:

  do { local $/ = undef; <$fh> }

or use L<File::Slurp>, which is even faster.

=head1 CAVEATS

Due to a bug in the current version of PPI (v1.119_03) and earlier,
the readline operator is often misinterpreted as less-than and
greater-than operators after a comma.  Therefore, this policy only
works well on the empty filehandle, C<<>>.  When PPI is fixed, this
should just start working.

=head1 CREDITS

Initial development of this policy was supported by a grant from the Perl Foundation.

=head1 AUTHOR

Chris Dolan <cdolan@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2007 Chris Dolan.  Many rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  The full text of this license
can be found in the LICENSE file included with this module

=cut

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 78
#   indent-tabs-mode: nil
#   c-indentation-style: bsd
# End:
# ex: set ts=8 sts=4 sw=4 tw=78 ft=perl expandtab :