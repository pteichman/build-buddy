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

# $Id: TargetList.pm 3068 2005-12-22 03:41:13Z v_thunder $

package Ximian::Web::TargetList;
use base qw/Ximian::Web::FormComp/;

use strict;
use Frontier::Client;

=head1 NAME

B<Ximian::Web::TargetList> - List of check boxes for picking targets

=head1 DESCRIPTION

A list of checkboxes, with labels beside them, for each target.  The
list of targets is obtained directly from the build master, as defined
in bb.conf.

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
    $self->{default} = $args->{default};
    $self->{widgets} = {};

    my $master  = new Frontier::Client
       (url => "http://$BBWeb::master:8080/RPC2")
        or die "Could not open connection to master server.";
    my $all = [ @{$master->call ("targets")} ];

    foreach my $tgt (@{$all}) {
	$self->{widgets}->{$tgt} =
	    Ximian::Web::CheckBox->new ({name => "$self->{name}_$tgt",
					 label => "$tgt"});
    }
    return bless ($self, $class);
}

sub process_init {
    my $self = shift;
    my %args = @_;
    $self->{processed} = 1;
    my @default;
    my @unavailable;
    my @on;

    @default = @{$self->default} if $self->default;

    # Set defaults
    foreach my $tgt (@default) {
	if (exists $self->{widgets}->{$tgt}) {
	    $self->{widgets}->{$tgt}->default (1);
	    # We cheat here - no need to get it from the children:
	    push @on, $tgt;
	} else {
	    push @{$self->{errors}}, "Target unavailable: $tgt";
	}
    }

    # Set our value
    $self->value (\@on);

    # Initialize children
    foreach my $w (values %{$self->{widgets}}) {
	$w->process_init;
    }
}

sub process_submit {
    my $self = shift;
    my %args = @_;
    my @on;

    $self->{processed} = 1;

    # Set children according to args, and get the checked ones in @on
    while (my ($tgt, $w) = each %{$self->{widgets}}) {
	$w->process_submit (p => $args{p});
	push @on, $tgt if $w->value;
    }

    # Set our value
    $self->value (\@on);
}

########################################################################

=head1 ACCESSORS

The following accessors are available:

=over 4

=item value

List of enabled targets.

=item default

Listref of targets enabled by default (before form submission).

=item label

A "pretty" name for the user to see.  Defaults to the name.  Note that
the targetlist won't display the label next to the itself--it's up to
you (the html/mason programmer) to do so, if you want to.

=back

=cut

Ximian::Web::TargetList->mk_accessors (qw/value default label/);

1;

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
