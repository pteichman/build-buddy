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

# $Id: BaseComp.pm 3068 2005-12-22 03:41:13Z v_thunder $

package Ximian::Web::BaseComp;
use base qw/Class::Accessor/;

use strict;

=head1 NAME

B<Ximian::Web::BaseComp> - Base class for all OO Mason components

=head1 DESCRIPTION

Base class for all Object-Oriented Mason components.

=cut

########################################################################

=head1 CLASS METHODS

=head2 new (key => value, ...)

Create a new component.  Supports setting a name, via name => "string".

=head1 INSTANCE METHODS

=head2 source

Returns the source of the mason data associated with this component,
uninterpreted.

=head2 comp

Returns the interpreted mason data associated with this component.

=head2 name

Returns the name of this component.

=head2 errors

Returns a list of any errors found during the processing of the
widget.

=cut

sub new {
    my $proto = shift;
    my $args = shift;

    my $class = ref $proto || $proto;
    my $self = $class->SUPER::new (@_);

    $self->{name} = $args->{name} or die "Must supply a name.";
    $self->{widget_dir} = ($args->{widget_dir} || "/widgets");

    # I don't know how else to do this.  It's gross! (but works)
    ($self->{classname}) = split /=/, $self;

    my $foo = join ('/', split ('::', $self->{classname}));
    $self->{comp_path} = "$self->{widget_dir}/$foo.mhtml";
    $self->{webui_comp_root} = ($args->{webui_comp_root} ||
				$BBWeb::webui_comp_root);
    $self->{file} = "$self->{webui_comp_root}$self->{comp_path}";
    $self->{errors} = [];

    return bless ($self, $class);
}

sub source {
    my $self = shift;

    unless ($self->{fh}) {
	open FH, $self->{file} or die "Can't open $self->{file}: $!";
	$self->{fh} = \*{FH};
    }
    my $fh = $self->{fh};
    local $/ = undef;
    $self->{start_data} ||= tell ($fh);
    seek ($fh, $self->{start_data}, 0);
    return <$fh>;
}

sub comp {
    my $self = shift;
    return $self->{comp} ||=
	$HTML::Mason::Commands::m->interp->make_component
	    (comp_file => $self->{file});
}

sub render {
    my $self = shift;
    return $HTML::Mason::Commands::m->comp ($self->comp,
					    self => $self);
}

sub name { return $_[0]->{name} }
sub errors { return @{$_[0]->{errors}} }

1;

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
