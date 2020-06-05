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

package Ximian::BB::Jail::File;

=head1 NAME

B<Ximian::BB::Jail::File> - Representation of a Jail Image file

=head1 DESCRIPTION

This class inherits from Ximian::BB::Jail.  It is the representation
of a jail image file.

=head1 SYNOPSIS

    use Ximian::BB::Jail::File;

    my $jail = Ximian::BB::Jail::Jail->new (path => "foo");
    my $newjail = Ximian::BB::Jail::Dir->new (path => "foo-1",
                                              jail => $jail);

=cut

use strict;
use File::Spec::Functions 'rel2abs';
use Scalar::Util qw/blessed/;

use base 'Ximian::BB::Jail';

use Ximian::XML::Simple;
use Ximian::Util ':all';
use Ximian::Run ':all';

########################################################################

=head1 CLASS METHODS

=head2 new (key => value, ...)

Not yet implemented.

=head2 load (key => value, ...)

Load a jail image file from disk.  Returns a new jail object.

=cut

sub new {
    my $class = shift;
    die "new: Options must be name => value pairs" if (@_ % 2);
    my @savedopts = @_;
    my $opts = { @_ };

    my $self = bless {}, $class;

    $self->{path} = rel2abs ($opts->{path}) or die "No jail path given.";
    die "Jail path already taken: $self->{path}\n" if -f $self->{path};

    # We don't lock for the unpack because export () does (and it's
    # in a different class, so we can't call it without deadlocking).

    if ($opts->{source}) {
	eval {
	    die "Source must be a jail object."
		unless $opts->{source}->isa ("Ximian::BB::Jail");

	    $opts->{source}->export (path => $self->get_cache_dir);
	    $self->{jail_path} = "$self->{cache}/jail";
	};
	if ($@) {
	    die "Could not unpack source: $@\n";
	}
	$self->SUPER::reload;
    }
    $self->reload (@savedopts) if -f $self->{path};
    return $self;
}

sub load {
    my $class = shift;
    my $opts = { @_ };
    my ($filetype) = get_cmd_output ("file $opts->{path}");
    die "Error detecting jail type.\n" unless $filetype;
    for ($filetype) {
	/current ar archive$/ && do {
	    my $self = bless {}, $class;
	    $self->reload (@_);
	    return $self;
	    last;
	};
	/: directory$/ && do {
	    die "Path is a directory, not a file.\n";
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

########################################################################

=head1 INSTANCE METHODS

=head2 reload (key => value, ...)

Cause the jail object to reload the saved metadata from disk.

=head2 save (key => value, ...)

Not yet implemented.

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

    my $path = ($opts->{path} || $self->{path});
    $self->{path} = rel2abs ($path) or die "No jail path given.";
    die "Jail image does not exist: $self->{path}\n" unless -f $self->{path};

    my $locked;
    eval { $locked = $self->lock (no_block => 1) };
    eval {
	# Make sure we have a brand-new cache dir
	$self->destroy_cache_dir;
	$self->get_cache_dir;

	pushd $self->{cache};
	run_cmd ("ar -x $self->{path} data.tar.gz") && die $!;
	run_cmd ("gunzip -c data.tar.gz | tar xf -") && die $!;
	$self->SUPER::reload;
	popd;
    };
    if (my $e = $@) {
	popd;
	$self->destroy_cache_dir;
	$self->unlock if $locked;
	die "Could not unpack jail image: $e";
    }

    $self->unlock if $locked;
    return $self;
}

sub save {
    my $self = shift;

    $self->lock;
    eval {
	pushd $self->get_cache_dir;
	$self->SUPER::save;
	run_cmd ("tar cf - data | gzip -c > data.tar.gz");
	run_cmd ("ar -r $self->{path} data.tar.gz");
	popd;
    };
    if ($@) {
	$self->destroy_cache_dir;
	$self->unlock;
	die $@;
    }
    if ($self->{jail_path} and -d $self->{jail_path}) {
	eval {
	    pushd $self->{jail_path};
	    run_cmd ("tar cf - . | gzip -c > $self->{cache}/jail.tar.gz");
	    run_cmd ("ar -r $self->{path} $self->{cache}/jail.tar.gz");
	    popd;
	};
	if ($@) {
	    $self->destroy_cache_dir;
	    $self->unlock;
	    die $@;
	}
    }
    $self->destroy_cache_dir;
    $self->unlock;
}

sub export {
    my $self = shift;
    die "export: Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    $opts->{path} = $opts->{path}->{path}
	if blessed $opts->{path}
	    and $opts->{path}->isa ("Ximian::BB::Jail::Dir::Handle");

    die "Could not lock \"$opts->{path}\"\n"
	unless lock_acquire ($opts->{path});

    eval {
	mkdirs $opts->{path};
	pushd $opts->{path};

	# The path should be empty before we do anything
	my @files = dirgrep { ! /^\./ } $opts->{path};
	die "export:  Jail path not empty:  $opts->{path}"
	    if (scalar @files);

	run_cmd ("ar -x $self->{path}") && die $!;

	# data.tar.gz unpacks to ./data/
	run_cmd ("gunzip -c data.tar.gz | tar xf -") && die $!;

	# jail.tar.gz unpacks to ./ (not ./jail/)
	mkdirs "jail";
	pushd "jail";
	run_cmd ("gunzip -c ../jail.tar.gz | tar xf -") && die $!;
	popd;

	run_cmd ("rm data.tar.gz jail.tar.gz") && die $!;

	popd;
	lock_release ($opts->{path});
    };
    if ($@) {
	popd;
	lock_release ($opts->{path});
	die $@;
    }
}

sub destroy {
    my $self = shift;
    $self->destroy_cache_dir;
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
	$self->destroy_cache_dir;

	# Make sure we release any stale locks
#	until ($self->unlock) {}; # this is wrong
    }
}

########################################################################

# Augment the base-class-provided method to make a new cache dir if we
# don't have one yet.  This allows us to save() a new instance.

sub new_metadata {
    my $self = shift;
    $self->get_cache_dir;
    return $self->SUPER::new_metadata (@_);
}

########################################################################

=head2 get_cache_dir

Makes a new cache directory if necessary and returns the path to it.
It is also saved in $self->{cache}, for internal/subclass use.

=head2 destroy_cache_dir

Destroys the cache directory.  Unsets $self->{cache}.

=cut

sub get_cache_dir {
    report (5, "Entering get_cache_dir");
    my $self = shift;

    if (exists $self->{cache} and -d $self->{cache}) {
	report (5, "Leaving get_cache_dir");
	return $self->{cache};
    }

    my $cache;
    eval {
	($cache) = get_cmd_output ("mktemp -d /tmp/bb_jail.XXXXXX");
    };
    if (my $e = $@) {
	die "Could not make temp dir: $@";
    }
    report (5, "Acquired cache dir: $cache");
    $self->{object_path} = "$cache/data/objects";
    $self->{settings_path} = "$cache/data/settings";
    $self->{cache} = $cache;
#    $self->unlock;

    report (5, "Leaving get_cache_dir");
    return $self->{cache};
}

sub destroy_cache_dir {
    report (5, "Entering destroy_cache_dir");
    my $self = shift;

    if ($self->{cache} and -d $self->{cache}) {
	run_cmd ("rm -rf $self->{cache}")
	    && report (2, "Could not destroy cache dir.");
	$self->{cache} = "";
    }
    report (5, "Leaving destroy_cache_dir");
}

1;

__END__

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
