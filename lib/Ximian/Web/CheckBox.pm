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

# $Id: CheckBox.pm 3068 2005-12-22 03:41:13Z v_thunder $

package Ximian::Web::CheckBox;
use base qw/Ximian::Web::FormComp/;

use strict;

=head1 NAME

B<Ximian::Web::CheckBox> - Check box form component

=head1 DESCRIPTION

A normal check box.

=cut

########################################################################

=head1 INSTANCE METHODS

=head2 new

Initialize the widget.

=head2 process_init

Initialize widget value to the default.

=head2 process_submit (p => $args)

Verify form data, and set the widget value accordingly.

=cut

sub new {
    my $proto = shift;
    my $args = $_[0];
    my $class = ref $proto || $proto;
    my $self = $class->SUPER::new (@_);
    $self->{label} = ($args->{label} || $self->name);
    $self->{default} = ($args->{default} || 0);
    return bless ($self, $class);
}

sub process_init {
    my $self = shift;
    my %args = @_;
    $self->{processed} = 1;
    $self->value ($self->default);
}

sub process_submit {
    my $self = shift;
    my %args = @_;

    $self->{processed} = 1;
    $self->value ($self->default);

    if (exists $args{p}->{$self->name}) {
	my $foo = $args{p}->{$self->name};
	$self->value (0);
	$self->value (1) if $foo;
    }
}

########################################################################

=head1 ACCESSORS

The following accessors are available:

=over 4

=item value

1 or 0 depending on whether the checkbox is checked or unchecked
(respectively).

=item default

What the value is set to before any user input.

=item label

A "pretty" name for the user to see.  Defaults to the name.  Note that
the checkbox won't display the label next to the itself--it's up to
you (the html/mason programmer) to do so, if you want to.

=back

=cut

Ximian::Web::CheckBox->mk_accessors (qw/value default label/);

1;

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
