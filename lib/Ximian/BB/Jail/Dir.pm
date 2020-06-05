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

package Ximian::BB::Jail::Dir;

=head1 NAME

B<Ximian::BB::Jail::Dir> - Jail object for an unpacked jail

=head1 DESCRIPTION

This class inherits from Ximian::BB::Jail.  It is the representation
of an unpacked jail, ready to be used directly either via a session,
or by calling the enter() method, which chroots into the jail.

=head1 SYNOPSIS

    use Ximian::BB::Jail::Dir;

    ### If jail "foo-1" doesn't exist ###

    my $jail = Ximian::BB::Jail::Dir->new (path => "foo-1");
    $jail->save; # saves metadata

    my $session = Ximian::BB::Jail::Session->new ($jail);
    $session->enter; # chroots into jail

    ### Or if jail "foo-1" already exists ###

    my $jail = Ximian::BB::Jail::Dir->load (path => "foo-1");

=cut

use strict;
use File::Spec::Functions 'rel2abs';
use Scalar::Util qw/blessed/;

use base 'Ximian::BB::Jail';

use Ximian::XML::Simple;
use Ximian::Util ':all';
use Ximian::Run ':all';
use Ximian::BB::Jail::Session;
use Ximian::BB::Jail::Metadata;

########################################################################

=head1 CLASS METHODS

=head2 new (key => value, ...)

Create a new Ximian::BB::Jail::Dir object.  If the source option is
given, a copy of that jail will be made.  If omitted, an empty jail is
made.

=head2 load (key => value, ...)

Create a new Ximian::BB::Jail::Dir object and populate it with an
existing unpacked jail.

=head2 get_new_handle (key => value, ...)

Find a new (unused) jail handle and claim it.  Takes two arguments:

=over 4

=item dir

Directory where the new jail should be created.

=item base

Base name for the new jail.  A serial will be added to it to create
the full jail handle.  Defaults to "unknown-jail".

=back

There is a maximum of 1024 jail serials that can be used for any given
base name.

=cut

sub new {
    my $class = shift;
    die "new: Options must be name => value pairs" if (@_ % 2);
    my @savedopts = @_;
    my $opts = { @_ };

    my $self = bless {}, $class;

    $opts->{path} = $opts->{path}->{path}
	if blessed $opts->{path}
	    and $opts->{path}->isa ("Ximian::BB::Jail::Dir::Handle");

    $self->{path} = rel2abs ($opts->{path}) or die "No jail path given.";

    # The path should be empty before we do anything
    if (-d $self->{path}) {
	my @files = dirgrep { ! /^\./ } $self->{path};
	die "new:  Jail path not empty:  $self->{path}" if scalar @files;
    }

    $self->{jail_path} = "$self->{path}/jail";
    $self->{object_path} = "$self->{path}/data/objects";
    $self->{settings_path} = "$self->{path}/data/settings";

    # We don't lock for the unpack because export () does (and it's
    # in a different class, so we can't call it without deadlocking).

    if ($opts->{source}) {
	eval {
	    die "Source must be a jail object."
		unless $opts->{source}->isa ("Ximian::BB::Jail");
	    $opts->{source}->export (path => $self->{path});
	};
	if ($@) {
	    die "Could not unpack source: $@\n";
	}
    }
    $self->reload (@savedopts) if -d $self->{path};
    return $self;
}	

sub load {
    my $class = shift;
    my $opts = { @_ };
    my ($filetype) = get_cmd_output ("file $opts->{path}");
    die "Error detecting jail type.\n" unless $filetype;
    for ($filetype) {
	/: directory$/ && do {
	    my $self = bless {}, $class;
	    $self->reload (@_);
	    return $self;
	    last;
	};
	/current ar archive$/ && do {
	    die "Path is a file, not a directory.";
	    last;
	};
	/gzip compressed data/ && do {
	    die "Old-style bb jail.\n";
	    last;
	};
	die "Unknown jail type: ($filetype)\n";
    }
    # unreachable
}

sub get_new_handle {
    my $class = shift;
    die "Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    die "Jaildir not found: $opts->{dir}" unless -d $opts->{dir};

    my $base = ($opts->{base} || "unknown-jail");
    my $serial = "0";
    my $handle = "$base-$serial";

    lock_acquire ("$opts->{dir}/get_new_handle");
    while (run_cmd ("mkdir $opts->{dir}/$handle >/dev/null 2>&1")) {
	die "Error:  Too many handles (1024)" if $serial == 1024;
	$serial++;
	$handle = "$base-$serial";
    }
    lock_release ("$opts->{dir}/get_new_handle");

    my $obj = { name => $handle,
		dir => $opts->{dir},
		path => "$opts->{dir}/$handle" };

    return bless $obj, "Ximian::BB::Jail::Dir::Handle";
}

########################################################################

=head1 INSTANCE METHODS

=head2 reload (key => value, ...)

Causes the jail object to reload the jail metadata from disk.

=head2 save (key => value, ...)

Causes the jail object to save the jail metadata to disk.

=head2 export (key => value, ...)

Writes a new directory-style jail to disk based on this jail.  The new
jail will be completely separate from this one.  Takes one argument,
path, which is the (relative or absolute) path where the new jail will
be stored.  If the directory exists, it must be empty.  Otherwise it
will be created.

=cut

sub reload {
    my $self = shift;
    die "reload: Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    die "Cannot reload after enter()" if $self->{chrooted};

    $opts->{path} = $opts->{path}->{path}
	if blessed $opts->{path}
	    and $opts->{path}->isa ("Ximian::BB::Jail::Dir::Handle");

    my $path = ($opts->{path} || $self->{path});
    $self->{path} = rel2abs ($path) or die "No jail path given.";
    die "Jail path does not exist: $self->{path}\n" unless -d $self->{path};
    $self->{jail_path} = "$self->{path}/jail";
    $self->{object_path} = "$self->{path}/data/objects";
    $self->{settings_path} = "$self->{path}/data/settings";

    my $locked;
    eval { $locked = $self->lock (no_block => 1) };

    eval {
	$self->SUPER::reload;

	if ($locked) {
	    # FIXME:  This won't work, because it would try to
	    # umount/remount even to just look at a jail's metadata.
	    if ($self->has_metadata ("mounts")) {
		my $meta = $self->get_metadata_tree ("mounts");
		foreach my $mount (@{$meta->{mounts}->{i}}) {
		    $self->umount (location => $mount->{location},
				   no_metadata => 1);
		    $self->mount (filesystem => $mount->{filesystem},
				  location => $mount->{location},
				  no_metadata => 1);
		}
	    }
	}
    };
    if ($@) {
	$self->unlock if $locked;
	die $@;
    }

    $self->unlock if $locked;
    return $self;
}

sub save {
    my $self = shift;

    die "Cannot save after enter()" if $self->{chrooted};

    $self->lock;
    eval {
	mkdirs $self->{jail_path};
	$self->SUPER::save;
    };
    if ($@) {
	$self->unlock;
	die $@;
    }
    $self->unlock;
}

sub export {
    my $self = shift;
    die "export: Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    $opts->{path} = $opts->{path}->{path}
	if blessed $opts->{path}
	    and $opts->{path}->isa ("Ximian::BB::Jail::Dir::Handle");

    die "No path given." unless $opts->{path};

    report (5, "Exporting jail $self->{path} to $opts->{path}");

    $self->lock;
    my $new = $opts->{path};

    die "Could not lock \"$new\"" unless lock_acquire ($new);

    if (-d $new) {
	# The path should be empty before we do anything
	my @files = dirgrep { ! /^\./ } $new;
	die "export:  Jail path not empty:  $new" if scalar @files;
    }

    eval {
	mkdirs "$new/data/objects";
	mkdirs "$new/data/settings";

	while (my ($name, $obj) = each %{$self->{objects}}) {
	    $obj->save (path => "$new/data/objects/$name");
	}
	while (my ($name, $obj) = each %{$self->{metadata}}) {
	    $obj->save (path => "$new/data/settings/$name.xml");
	}

	my @mounts;
	if ($self->has_metadata ("mounts")) {
	    my $meta = $self->get_metadata_tree ("mounts");
	    @mounts = @{$meta->{mounts}->{i}};
	}

	foreach my $mount (@mounts) {
	    $self->umount (location => $mount->{location},
			   no_metadata => 1);
	}

	eval {
	    pushd $new;
	    # This is likely more portable than cp -r
	    run_cmd ("(cd $self->{path}; tar cf - jail) | tar xf -") && die $!;
	    if (-f "/etc/resolv.conf") {
		run_cmd ("cp /etc/resolv.conf jail/etc/resolv.conf") && die $!;
	    }
	    popd;
	};
	if (my $e = $@) {
	    popd;
	    die $@;
	}

	foreach my $mount (@mounts) {
	    $self->mount (filesystem => $mount->{filesystem},
			  location => $mount->{location},
			  no_metadata => 1);
	}
    };
    if (my $e = $@) {
	lock_release ($new);
	$self->unlock;
	die $@;
    }
    lock_release ($opts->{path});
    $self->unlock;
}

sub destroy {
    my $self = shift;

    $self->kill_all_procs;

    # umount will raise an exception if there is a problem,
    # which will cause the destroy() to stop (which we want)

    if ($self->has_metadata ("mounts")) {
	my $meta = $self->get_metadata_tree ("mounts");
	foreach my $mount (@{$meta->{mounts}->{i}}) {
	    $self->umount (location => $mount->{location},
			   no_metadata => 1);
	}
    }

    return $self->SUPER::destroy;
}

sub DESTROY {
    my $self = shift;

    # Destructors can override $@, causing exceptions to "dissapear".
    # Making it local solves that problem:
    local $@;

    # We don't want to make any changes to the disk if we are only
    # a subprocess in run_cmd -- check for that:

    unless ($Ximian::Run::subprocess_flag) {
	# Make sure we release any stale locks
# 	until ($self->unlock) {}; # this is wrong
    }
}

########################################################################

=head2 path

Returns the path to the whole jail (including the metadata).

=head2 jail_path

Returns the path to the jail chroot only.

=head2 object_path

Returns the path to where the serialized objects are stored.

=head2 settings_path

Returns the path to where the jail settings (and the settings of
serialized obejcts) are stored.

=cut

sub path {
    my $self = shift;
    return $self->{path};
}

sub jail_path {
    my $self = shift;
    return $self->{jail_path};
}

sub object_path {
    my $self = shift;
    return $self->{object_path};
}

sub settings_path {
    my $self = shift;
    return $self->{settings_path};
}

########################################################################

=head2 get_object ($object_id)

Returns the object of id $object_id that is associated with this jail.

=head2 register_object ($object)

Register a serializable object with the jail.  The object must derive
from the Ximian::BB::Jail::Serializable class.  If a session with the
same session ID is already registered, it is replaced with the new
one.

=cut

sub get_object {
    my $self = shift;
    my ($object_id) = @_;
    die "Ximian::BB::Jail::Dir: Invalid object"
	unless exists $self->{objects}
	    and exists $self->{objects}->{$object_id};
    return $self->{objects}->{$object_id};
}

sub register_object {
    my $self = shift;
    my ($object) = @_;
    die "Object is is not serializable."
	unless $object->isa ("Ximian::BB::Jail::Serializable");

    my $id = $object->object_id;
    $object->set_path ("$self->{object_path}/$id");
    $self->{objects}->{$id} = $object;
}

########################################################################

=head2 mount (key => val, ...)

Mounts a filesystem from the host machine to a location inside the
jail, using the "bind" method.  Valid keys are:

=over 4

=item filesystem

Path from the host machine that will be mounted inside the jail.  This
is a required key.

=item location

Location relative to the jail path where the filesystem will be
mounted.  If not specified, the same path as the filesystem is used.

=item no_metadata

Don't add the mount to the jail metadata, or use the existing metadata
to check for mounted filesystems.  This option should be used with
care.

=back

=head2 umount (key => val, ...)

Unmounts a filesystem from the jail.  Valid keys are:

=over 4

=item location

Mount point to unmount (relative to the jail path).

=item no_metadata

Don't remove the mount from the jail metadata.  This option should be
used with care.

=back

=cut

sub mount {
    my $self = shift;
    die "mount: Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    die unless -d $opts->{filesystem};
    my $filesystem = $opts->{filesystem};
    my $location = ($opts->{location} || $opts->{filesystem});

    my $meta = $self->get_or_new_metadata_tree ("mounts");
    $meta->{mounts}->{i} = [] unless defined $meta->{mounts}->{i};

    unless ($opts->{no_metadata}) {
	foreach (@{$meta->{mounts}->{i}}) {
	    die "Mount point already in use."
		if $_->{location} eq $location;
	}
    }

    mkdirs "$self->{jail_path}/$location";

    my $hostos = `uname`;
    if ($hostos =~ /SunOS/) {
	run_cmd ("mount -F lofs $filesystem $self->{jail_path}/$filesystem");
    } else {
	run_cmd ("mount --bind $filesystem $self->{jail_path}/$filesystem");
    }

    return if $opts->{no_metadata};

    # Add to the list
    push @{$meta->{mounts}->{i}},
	{ filesystem => $opts->{filesystem},
	  location => $opts->{location} };
}

sub umount {
    my $self = shift;
    die "mount: Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    die "No location specified." unless $opts->{location};

    # run_cmd_async can be made sync with an option
    my $run_opts = {sync => 1, sync_logging => 1};
    my $cmd = "umount $self->{jail_path}/$opts->{location}";

    # Since we mount with bind, any given directory can be mounted
    # multiple times.  So we loop until mount says it's not mounted.

    while (my $ret = run_cmd_async ($run_opts, $cmd)) {
	my $out = (shift @{$ret->{lines}} || ""); # so the matches never die
	last if $out =~ /not mounted/ or $out =~ /not found/;

	# Don't keep looping if it there was some other error
	if ($out or $ret->{exit_status}) {
	    die "Could not unmount $opts->{location}: $out";
	}
    }

    return if $opts->{no_metadata};

    # Remove from the list
    my $meta = $self->get_or_new_metadata_tree ("mounts");
    $meta->{mounts}->{i} = [] unless defined $meta->{mounts}->{i};
    @{$meta->{mounts}->{i}} =
	grep {$_->{location} ne $opts->{location}} @{$meta->{mounts}->{i}};
}

########################################################################

=head2 kill_all_procs

Kill all processes that were started inside the jail.

=cut

sub kill_all_procs {
    my $self = shift;

    # kill all processes that have the jail as their rootdir
    my @proclist;
    opendir PROCDIR, "/proc" || die "opendir: $!";
    while (my $proc = readdir PROCDIR) {
	next unless $proc =~ /^\d*$/;
	next unless my $proc_path = readlink "/proc/$proc/root";
	next unless $self->{jail_path} eq $proc_path;
	system ("kill -TERM $proc");
	push @proclist, $proc;
    }

    # now go through and kill -9 the stragglers
    foreach my $proc (@proclist) {
	if (-d "/proc/$proc" && $self->{jail_path} eq (readlink "/proc/$proc/root")) {
            system ("kill -9 $proc");
	}
    }
    closedir PROCDIR;

    return 1;
}

########################################################################

=head2 enter

Calling this method will cause a chroot into the jail.  This requires
superuser capabilities.

Any commands (e.g., those executed with 'run_cmd', or just a plain
'system') run after calling this method will be run inside the jail.

This method is not reversible; i.e., there is no leave() method.  In
addition, other methods such as save() will not work after calling
enter().

=cut

sub enter {
    my $self = shift;
    chdir $self->{jail_path}
	or die "Ximian::BB::Jail::Dir: Could not chdir: $!\n";
    chroot $self->{jail_path}
	or die "Ximian::BB::Jail::Dir: Could not chroot: $!\n";
    $self->{chrooted} = 1; # so that save() will die
}

1;

__END__

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
