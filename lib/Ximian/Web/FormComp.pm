# Copyright 2003 Ximian, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

# $Id: FormComp.pm 3068 2005-12-22 03:41:13Z v_thunder $

package Ximian::Web::FormComp;
use base 'Ximian::Web::BaseComp';

use strict;

=head1 NAME

B<Ximian::Web::FormComp> - Form component base class

=head1 DESCRIPTION

All form widget components inherit from this one.  It is different
from the standard base component in that it takes care of
initialization before and after form submission.  Subclasses must
implement 'process_init' and 'process_submit' methods (see below).

=cut

########################################################################

=head1 CLASS METHODS

=head2 new (key => value, ...)

Create a new form widget and return it.  Does not process the
widget--you must call the process() method before calling comp() or
render().

=head2 process

Initializes the widget before form submission, or if the 'p' argument
is provided (which should be a ref to %ARGS), then processes the user
input and sets values accordingly.  Any errors are available via the
'errors' method.  All arguments are passed on to process_init and
process_submit, so they can accept any other settings the widgets wish
to provide.

=head2 process_init

This method must be implemented by all subclasses.  It is called on
object creation, when no ARGS hash is present (i.e., before form
submission).  The method should then initialize any values for the
widget to defaults.  It should also set $self->{processed} = 1.

=head2 process_submit

This method must be implemented by all subclasses.  It is called on
object creation, when the ARGS hash *is* present (i.e., after form
submission).  The method should verify the data, and set the widget
accordingly.  It should also set $self->{processed} = 1.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $self = $class->SUPER::new (@_);
    $self->{processed} = 0;
    return bless ($self, $class);
}

sub process_init { die "Component $_[0]->{name} doesn't implement process_init." }
sub process_submit { die "Component $_[0]->{name} doesn't implement process_submit." }

sub comp {
    my $self = shift;
    die "Widget $self->{name} cannot be rendered until it has been processed."
	unless $self->{processed};
    $self->SUPER::comp (@_);
}

1;

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
