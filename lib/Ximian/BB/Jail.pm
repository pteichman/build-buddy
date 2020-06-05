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

package Ximian::BB::Jail;

=head1 NAME

B<Ximian::BB::Jail> - Base class for BB Jails

=head1 DESCRIPTION

This base class defines the basic interface of BB Jails, and their
default behavior.

=head1 SYNOPSIS

    use Ximian::BB::Jail;

    my $jail = Ximian::BB::Jail->load_guess (path => "my-distro.jailimg");

    # See Ximian::BB::Jail::File and Ximian::BB::Jail::Dir
    # for what you can do with these objects.

=cut

use strict;

use Ximian::Util ':all';
use Ximian::Run ':all';
use Ximian::BB::Jail::Metadata;

########################################################################

=head1 CLASS METHODS

=head2 new (key => value, ...)

This method must be overridden in a subclass.

=head2 load (key => value, ...)

This method must be overridden in a subclass.

=head2 reload (key => value, ...)

This method must be overridden in a subclass.

=head2 save (key => value, ...)

This method must be overridden in a subclass.

=head2 export (key => value, ...)

This method must be overridden in a subclass

=head2 destroy (key => value, ...)

This method must be overridden in a subclass

=cut

# See Jail/Dir.pm for examples

sub new {
    die "This method must be overridden in a subclass.";
}
sub load {
    die "This method must be overridden in a subclass.";
}
sub reload {
    my $self = shift;

    if ($self->{object_path} and -d $self->{object_path}) {
	foreach (dirgrep { ! /^\./ } $self->{object_path}) {
	    Ximian::BB::Jail::Serializable->load
		    (path => "$self->{object_path}/$_", jail => $self);
	}
    }
    if ($self->{settings_path} and -d $self->{settings_path}) {
	foreach (dirgrep { /^[^.]+.*\.xml$/ } $self->{settings_path}) {
	    m/(.*)\.xml$/;
	    $self->{metadata}->{$1} = Ximian::BB::Jail::Metadata->load
		(path => "$self->{settings_path}/$_");
	}
    }
    $self->get_metadata_tree ("main"); # must exist or we die()
    return 1;
}
sub save {
    my $self = shift;

    if ($self->{object_path}) {
	mkdirs $self->{object_path};
	$_->save foreach (values %{$self->{objects}});
    }
    if ($self->{settings_path}) {
	mkdirs $self->{settings_path};
	$_->save foreach (values %{$self->{metadata}});
    }
}
sub export {
    die "This method must be overridden in a subclass.";
}

sub destroy {
    my $self = shift;
    run_cmd ("rm -rf $self->{path}");
    until ($self->unlock) {}; # Make sure we release any stale locks
    return 1;
}

sub destroy_async {
    my $self = shift;
    return run_cmd_async ({run_cb => \&{$self->destroy},
			   logging_cb => sub {
			       my $context = shift;
			       return unless @_;
			       print STDERR "Error destroying jail:\n";
			       print "    $_\n" foreach (@_);
			   }});
}

########################################################################

=head2 load_guess (key => value, ...)

Load a Ximian::BB::Jail::Dir or Ximian::BB::Jail::File object,
guessing by whether the path points to a directory or a file.

Raises an exception when the path is not readable or is unset.

=head2 load_guess_multiple (key => value, ...)

Similar to load_guess, but works on a directory that contains jails
and loads them all.  Returns a list of jail objects (either dir or
file).  Takes one argument, dir, which is the path to load the jails
from.

=cut

sub load_guess {
    my $class = shift;
    die "load_guess: Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    die "No jail path given." unless $opts->{path};

    if (-d $opts->{path}) {
	require Ximian::BB::Jail::Dir;
	return Ximian::BB::Jail::Dir->load (%$opts);
    } elsif (-f $opts->{path}) {
	require Ximian::BB::Jail::File;
	return Ximian::BB::Jail::File->load (%$opts);
    } else {
	die "Jail path not found: $opts->{path}" 
    }
}

sub load_guess_multiple {
    my $class = shift;
    die "Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    die "Invalid jaildir" unless $opts->{dir} and -d $opts->{dir};

    my @jails;
    foreach (dirgrep { ! /^\./ } $opts->{dir}) {
	my $jail;
	eval {$jail = load_guess ($class, path => "$opts->{dir}/$_")};
        if (my $e = $@) {
            report (6, "Warning: Couldn't load jail \"$_\": $e");
            next;
        }
	push @jails, $jail;
    }
    return @jails;
}

########################################################################

=head2 get_path (key => value, ...)

Returns the path this jail points to.

=cut

sub get_path {
    my $self = shift;
    return $self->{path};
}

########################################################################

=head2 new_metadata ($metadata_id)

Makes a new metadata object of the given name and returns it.  The
name must be unique for this jail, and composed of alphanumerics and
dashes/underscores.

=head2 get_metadata ($metadata_id)

Returns the metadata object of the given name.  The object must
already exist in the jail (though not necessarily have been saved to
disk yet).

=head2 get_metadata_tree ($metadata_id)

Like get_metadata, but returns the xml tree only.

=head2 set_metadata_tree ($metadata_id, $tree)

Convenience function, equivalent to:

my $meta = get_metadata ($metadata_id);
$meta->set_xml_tree ($tree);

=head2 get_or_new_metadata ($metadata_id)

Convenience function to make a new metadata of the given name if it
doesn't already exist, or load it if it does, and return it.  Useful
when the caller doesn't care if the metadata exists already or not.

=head2 get_or_new_metadata_tree ($metadata_id)

Like get_or_new_metadata, but returns the xml tree only.

=head2 get_metadata_sets ()

Returns an array of all the metadata IDs registered.

=head2 has_metadata ($metadata_id)

Returns 1 if there is a metadata registered with the given name, 0
otherwise.

=cut

sub new_metadata {
    my $self = shift;
    my ($metadata_id) = @_;
    die "Metadata ID already exists"
	if exists $self->{metadata}
	    and exists $self->{metadata}->{$metadata_id};
    $self->{metadata}->{$metadata_id} = Ximian::BB::Jail::Metadata->new
	(path => "$self->{settings_path}/$metadata_id.xml");
    return $self->{metadata}->{$metadata_id};
}

sub get_metadata {
    my $self = shift;
    my ($metadata_id) = @_;
    die "Metadata ID not found"
	unless exists $self->{metadata}
	    and exists $self->{metadata}->{$metadata_id};
    return $self->{metadata}->{$metadata_id};
}

sub get_metadata_tree {
    my $self = shift;
    my $meta = $self->get_metadata (@_);
    return $meta->get_xml_tree;
}

sub set_metadata_tree {
    my $self = shift;
    my $metadata_id = shift;
    my $tree = shift;
    my $meta = $self->get_metadata ($metadata_id);
    return $meta->set_xml_tree ($tree);
}

sub get_or_new_metadata {
    my $self = shift;
    my ($metadata_id) = @_;
    my $data;
    eval {
	$data = $self->new_metadata ($metadata_id);
    };
    if ($@ =~ /Metadata ID already exists/) {
	$data = $self->get_metadata ($metadata_id);
    } elsif ($@) {
	die $@;
    }
    return $data;
}

sub get_or_new_metadata_tree {
    my $self = shift;
    my $meta = $self->get_or_new_metadata (@_);
    return $meta->get_xml_tree;
}

sub get_metadata_sets {
    my $self = shift;
    return keys %{$self->{metadata}};
}

sub has_metadata {
    my $self = shift;
    my ($metadata_id) = @_;
    return 1 if exists $self->{metadata}->{$metadata_id};
    return 0;
}

########################################################################

=head2 lock (key => value, ...)

Create a lockfile so that other instances of the same jail will not
touch it.  The lock is created using Ximian::Util's locking routines.
There is the addition of refcounting, so that methods of the same
instance of this class can lock multiple times (so they can call other
methods of this class).

=head2 unlock (key => value, ...)

Release the lock on the jail.  If lock() was called multiple times,
then only lower the refcount.

=cut

sub lock {
    my $self = shift;
    die "lock: Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    my $ref = defined $self->{lock_refcount}? $self->{lock_refcount} : 0;
    report (7, "Locking jail $self->{path}, refcount: $ref");

    if (lock_acquire $self->{path}, "no_pid") {
	$self->{lock_refcount}++;
    } else {
	if ($self->{lock_refcount}) {
	    $self->{lock_refcount}++;
	} else {
	    return 0 if $opts->{no_block};
	    lock_acquire_safe_spin $self->{path}, 5, "no_pid";
	}
    }
    return 1;
}

sub unlock {
    my $self = shift;

    my $ref = defined $self->{lock_refcount}? $self->{lock_refcount} : 0;
    report (7, "Unlocking jail $self->{path}, refcount: $ref");

    $self->{lock_refcount}--
	if ($self->{lock_refcount});

    # Return 0 if we still hold the lock
    return 0 if ($self->{lock_refcount});

    # Release if it's now at 0, and return 1
    lock_release $self->{path}, "no_pid";
    return 1;
}

1;

__END__

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
