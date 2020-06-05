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

package Ximian::BB::Jail::Serializable;

=head1 NAME

B<Ximian::BB::Jail::Serializable> - Base class for objects that can be serialized to jails

=head1 DESCRIPTION

Objects which want to be seamlessly serialized and restored into a
jail inherit from this class.

=head1 SYNOPSIS

    use base 'Ximian::BB::Jail::Serializable';

=cut

use strict;
use Data::UUID;
use Storable qw/store retrieve dclone/;

use Ximian::XML::Simple;
use Ximian::Util ':all';

########################################################################

=head1 CLASS METHODS

=head2 new (option => value, ...)

Create a new jail-serializable object.  Valid options are:

=over 4

=item jail

Ximian::BB::Jail object to use.  This is a required argument.

=back

=head2 load (option => value, ...)

Loads a serialized object and returns it.  Options are:

=over 4

=item path

Path to the object directory that contains the serialized data.

=item jail

Jail object associated with this object.

=back

=cut

sub new {
    my $class = shift;
    die "Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    die "Invalid jail object (must be Ximian::BB::Jail)"
	unless $opts->{jail}->isa ("Ximian::BB::Jail");

    # NOTE:  This is generally unadvisable, but we allow it
    # here so that subclasses can call $self->SUPER::new
    my $self = ref $class? $class : bless {}, $class;

    $self->{jail} = $opts->{jail};
    $self->{object_id} = $self->new_object_id;
    $self->{jail}->register_object ($self); # sets $self->{path}
    return $self;
}

sub load {
    my $class = shift;
    die "Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    die "No object path given." unless $opts->{path};
    die "Object path not found: $opts->{path}" unless -d $opts->{path};
    die "Invalid jail object (must be Ximian::BB::Jail)"
	unless $opts->{jail}->isa ("Ximian::BB::Jail");

    my $self = retrieve ("$opts->{path}/storable.data");
    $self->{jail} = $opts->{jail};
    $self->{jail}->register_object ($self); # sets $self->{path}
    return $self;
}

########################################################################

=head1 INSTANCE METHODS

=head2 reload

=head2 save

=cut

sub reload {
    my $self = shift;
    die "Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    # FIXME:  Should we reload $self->{path}/storable.data here?

    $self->{jail}->register_object ($self); # sets $self->{path}
    return $self;
}

sub save {
    my $self = shift;
    my $copy = dclone ($self);
    die "Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    my $path = ($opts->{path} || $self->{path});
    mkdirs $path;
    delete $copy->{jail}; # We'll restore it on load
    $self->pre_serialize_hook ($copy);
    store ($copy, "$path/storable.data");
}

sub pre_serialize_hook { };

########################################################################

=head2 path

Returns the object's private path.  This is where the
Storable-serialized information is kept, as well as any other
non-user-editable files subclasses want to store there.

=head2 set_path

Sets the object's private path.

=cut

sub path {
    my $self = shift;
    return $self->{path};
}

sub set_path {
    my $self = shift;
    return $self->{path} = shift;
}

########################################################################

=head2 object_id

Returns this object's ID which can be used to uniquely identify it
within a jail.

=head2 new_object_id

Create a new object ID and return it.  Subclasses will want to
override this method if they wish to use something other than a UUID.
This is useful if the subclass cannot coexist with other instances of
itself--in that case, new_object_id() should return a static string.

=cut

sub object_id {
    my $self = shift;
    return $self->{object_id};
}

sub new_object_id {
    my $self = shift;
    my $uuidgen = Data::UUID->new;
    my $sid = $uuidgen->create;
    return $uuidgen->to_string ($sid);
}

1;

__END__

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
