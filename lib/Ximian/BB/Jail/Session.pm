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

package Ximian::BB::Jail::Session;

=head1 NAME

B<Ximian::BB::Jail::Session> - A user session for a local jail

=head1 DESCRIPTION



=head1 SYNOPSIS

    ...

=cut

use strict;

use base 'Ximian::BB::Jail::Serializable';

use Ximian::Util ':all';
use Ximian::Run; # can't import, we define run_cmd too
use Ximian::BB::Jail::Metadata;

########################################################################

=head1 CLASS METHODS

=head2 new (option => value, ...)

See C<Ximian::BB::Jail::Serializable> for more options (including
required ones!).  This C<new> adds one option:

=head2 load (key => value, ...)



=cut

sub new {
    my $class = shift;
    die "Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    my $self = bless {}, $class;
    $self->SUPER::new (@_);
    $self->{metadata} = Ximian::BB::Jail::Metadata->new
	(path => "$self->{path}/metatata.xml");
    $self->{logging_cb} = $opts->{logging_cb} if $opts->{logging_cb};
    return $self;
}

sub load {
    my $class = shift;
    die "Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    my $tmp = bless {}, $class;
    my $self = $tmp->SUPER::load (@_); # SUPER::load returns a new object
    $self->{metadata} = Ximian::BB::Jail::Metadata->new
	(path => "$self->{path}/metatata.xml");
    $self->{logging_cb} = $opts->{logging_cb} if $opts->{logging_cb};
    return $self;
}

########################################################################

=head1 INSTANCE METHODS

=cut

sub reload {
    my $self = shift;
    $self->SUPER::reload (@_);
    $self->{metadata}->reload;
}

sub save {
    my $self = shift;
    $self->SUPER::save (@_);
}

sub pre_serialize_hook {
    my $self = shift;
    my $clone = shift;
    delete $clone->{metadata};
    delete $clone->{logging_cb};
}

########################################################################

=head2 run_cmd (\&callback, @command)

Runs a command in the session's jail.  The callback routine is called
at most once for every log step seconds (except when the child process
ends, when any remaining logs are processed immediately).  Arguments
to the callback are a hash containing info about the current run_cmd
context.  Currently, the only keys defined are:

=over 4

=item command_num

How many commands have been run in this session total.

=item first_callback

Whether this is the first callback for the current command.

=back

=cut

sub _jail_enter_cb {
    my $context = shift;
    my $meta = $context->{data}->{session}->{metadata};

    # chroot
    $context->{data}->{session}->{jail}->enter;

    # change user if requested
    $> = $meta->{uid} if $meta->{uid};

    # set-up environment
    chdir $meta->{cwd} if $meta->{cwd};
}

sub common_opts {
    my $self = shift;
    my $name = shift;

    # Keep track of how many commands we've run total
    ($self->{command_num} ||= 0) += 1;

    my %run_opts;
    $run_opts{data}->{name} = $name if $name;
    $run_opts{data}->{session} = $self;
    $run_opts{data}->{command_num} = $self->{command_num};
    $run_opts{logging_cb} = $self->{logging_cb} if $self->{logging_cb};
    $run_opts{pre_run_cb} = \&_jail_enter_cb
	unless $self->{jail}->{chrooted};
    return \%run_opts;
}

sub run_cmd_async {
    my $self = shift;
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my @cmd = @_;
    my $run_opts = $self->common_opts ($opts{name});
    return Ximian::Run::run_cmd_async ($run_opts, @cmd);
}

sub run_cmd {
    my $self = shift;
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my @cmd = @_;
    my $run_opts = $self->common_opts ($opts{name});
    $run_opts->{sync} = 1;
    return Ximian::Run::run_cmd ($run_opts, @cmd);
}

sub get_cmd_output {
    my $self = shift;
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my @cmd = @_;

    # Do we want to increment command_num for these commands...?
    my $run_opts = $self->common_opts ($opts{name});
    $run_opts->{ignore_errors} = $opts{ignore_errors};
    delete $run_opts->{logging_cb}; # We want to return the output

    return Ximian::Run::get_cmd_output ($run_opts, @_);
}

1;

__END__

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
