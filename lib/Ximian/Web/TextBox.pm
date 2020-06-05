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

# $Id: TextBox.pm 3068 2005-12-22 03:41:13Z v_thunder $

package Ximian::Web::TextBox;
use base qw/Ximian::Web::FormComp/;

use strict;

=head1 NAME

B<Ximian::Web::TextBox> - Text input box form component

=head1 DESCRIPTION

A normal text input box.

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
    $self->{default} = ($args->{default} || "");
    $self->{width} = ($args->{width} || "20");
    $self->{maxlength} = ($args->{maxlength} || "20");
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
	if ($self->maxlength < length ($foo)) {
	    push @{$self->{errors}}, "String too long.";
	}
	$self->value ($foo);
    }
}

########################################################################

=head1 ACCESSORS

The following accessors are available:

=over 4

=item value

String contained in the textbox.

=item default

What the value is set to before any user input.

=item label

A "pretty" name for the user to see.  Defaults to the name.  Note that
the textbox won't display the label next to the textbox--it's up to
you (the html/mason programmer) to do so, if you want to.

=item width

Visible width of the box.

=item maxlength

Length in characters of the value.  Will trigger an error otherwise
(see the errors method of Ximian::Web::BaseComp for how to get it).

=back

=cut

Ximian::Web::TextBox->mk_accessors (qw/value default label width maxlength/);

1;

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
