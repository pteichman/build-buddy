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

package Ximian::RCD;

=head1 NAME

B<Ximian::RCD> - Object to interact with RCD

=head1 DESCRIPTION



=head1 SYNOPSIS

    ...

=cut

use strict;
use Carp;

use Ximian::Util ':all';
use Ximian::Run ':all';
use Ximian::BB::Macros ':all';
use Ximian::BB::Globals;

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
                  )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

=head1 CLASS METHODS

=head2 instance (option => value, ...)

=cut

my $singleton;
my $configured;

sub instance {
    my $class = shift;
    die "Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    my $self = bless {}, $class;
    $self = $singleton if defined $singleton;
    $singleton = $self;

    $self->use_system (($opts->{use_system} || 1));

    $self->mcookie (($opts->{mcookie} || $self->{mcookie} || ""));
    $self->partnernet (($opts->{partnernet} || $self->{partnernet} || ""));
    $self->rcd_conf (($opts->{rcd_conf} || $self->{rcd_conf} || []));
    $self->rcd_pass (($opts->{rcd_pass} || $self->{rcd_pass} || [])); # "distro::view,install,remove,upgrade,subscribe"
    $self->rcd_datadir (($opts->{rcd_datadir} || $self->{rcd_datadir} || "/var/lib/rcd"));
    $self->rcd_confdir (($opts->{rcd_confdir} || $self->{rcd_confdir} || "/etc/ximian"));

    $self->rug_path (($opts->{rug_path} || $self->{rug_path} || "/usr/bin/rug"));
    $self->rcd_path (($opts->{rcd_path} || $self->{rcd_path} || "/usr/sbin/rcd"));

    return $self;
}

########################################################################

=head1 INSTANCE METHODS

=cut

sub use_system {
    my $self = shift;
    my ($val) = @_;
    $self->{use_system} = $val if defined $val;
    return $self->{use_system};
}

sub mcookie {
    my $self = shift;
    my ($val) = @_;
    $self->{mcookie} = $val if defined $val;
    return $self->{mcookie};
}

sub partnernet {
    my $self = shift;
    my ($val) = @_;
    $self->{partnernet} = $val if defined $val;
    return $self->{partnernet};
}

sub rug_path {
    my $self = shift;
    my ($val) = @_;
    $self->{rug_path} = $val if defined $val;
    return $self->{rug_path};
}

sub rcd_path {
    my $self = shift;
    my ($val) = @_;
    $self->{rcd_path} = $val if defined $val;
    return $self->{rcd_path};
}

sub rcd_datadir {
    my $self = shift;
    my ($val) = @_;
    $self->{rcd_datadir} = $val if defined $val;
    return $self->{rcd_datadir};
}

sub rcd_confdir {
    my $self = shift;
    my ($val) = @_;
    $self->{rcd_confdir} = $val if defined $val;
    return $self->{rcd_confdir};
}

sub rcd_conf {
    my $self = shift;
    my (@val) = @_;
    $self->{rcd_conf} = \@val if @val;
    return @{($self->{rcd_conf} || [])};
}

sub rcd_pass {
    my $self = shift;
    my (@val) = @_;
    $self->{rcd_pass} = \@val if @val;
    return @{($self->{rcd_pass} || [])};
}

########################################################################

sub write_file {
    my ($file, @lines) = @_;
    open FILE, ">$file" or die "Could not open \"$file\": $!\n";
    print FILE foreach (@lines);
    close FILE;
}

sub setup {
    my $self = shift;

    $self->shutdown;
    return 0 if $self->ping;

    if ($configured) {
        # we're reconfiguring, just blow away our previous one
        foreach my $d (($self->{rcd_confdir}, $self->{rcd_datadir})) {
            run_cmd ("rm -rf $d");
            mkdirs $d;
        }
    } else {
        foreach my $d (($self->{rcd_confdir}, $self->{rcd_datadir})) {
            if (-d $d) {
                run_cmd ("rm -rf $d.bb.backup");
                run_cmd ("mv $d $d.bb.backup");
            }
            mkdirs $d;
        }
    }

    my $dir = $self->{rcd_confdir};
    foreach my $file (qw/mcookie partnernet/) {
        write_file ("$dir/$file", $self->{$file}) if exists $self->{$file};
    }
    write_file ("$dir/rcd.passwd", $self->{rcd_pass}) if exists $self->{rcd_pass};
    write_file ("$dir/rcd.conf", $self->{rcd_conf}) if exists $self->{rcd_conf};

    $configured = 1;
}

sub start {
    my $self = shift;

    $self->setup unless $self->use_system;
    return 1 if $self->ping;

    my $sudo = "";
    $sudo = "sudo " if $>;

    if (run_cmd ("$sudo$self->{rcd_path} -r --no-services")) {
	reportline (1, "Could not run $self->{rcd_path}");
        return 0;
    }

    # make sure it's running
    my $slept;
    my $done;
    until ($done) {
	eval {
	    $self->ping;
	    $done = 1;
	};
	# We can't use SIGALRM:
	safe_sleep (5 * ++$slept);
        if ($slept >= 60/5) {
            reportline (1, "Error starting rcd.");
            return 0;
        }
    }
    return 1;
}

sub stop {
    my $self = shift;

    return 1 unless $configured;
    return 0 unless $self->shutdown;

    # Restore config
    foreach my $d (($self->{rcd_confdir}, $self->{rcd_datadir})) {
        run_cmd ("rm -rf $d");
        if (-d "$d.bb.backup") {
            run_cmd ("mv $d.bb.backup $d");
        }
    }

    # FIXME: should we start rcd again with its original config...?

    return 1;
}

########################################################################

sub ping {
    my $self = shift;
    reportline (2, "Running: $self->{rug_path} ping");
    if (run_cmd ("$self->{rug_path} ping")) {
	reportline (1, "Could not ping rcd daemon");
        return 0;
    }
    return 1;
}

sub restart {
    my $self = shift;
    reportline (2, "Running: $self->{rug_path} restart");
    if (run_cmd ("$self->{rug_path} restart")) {
	reportline (1, "Could not restart rcd daemon");
        return 0;
    }
    return 1;
}

sub shutdown {
    my $self = shift;
    reportline (2, "Running: $self->{rug_path} shutdown");
    if (run_cmd ("$self->{rug_path} shutdown")) {
	reportline (1, "Could not shutdown rcd daemon");
        return 0;
    }
    return 1;
}

sub refresh {
    my $self = shift;
    reportline (2, "Running: $self->{rug_path} refresh");
    if (run_cmd ("$self->{rug_path} refresh")) {
	reportline (1, "Could not refresh rcd daemon");
        return 0;
    }
    return 1;
}

########################################################################

sub set_var {
    my $self = shift;
    my %settings = @_;
    my $error = 0;
    while (my ($key, $val) = each %settings) {
        reportline (2, "Running: $self->{rug_path} set $key $val");
	if (run_cmd ("$self->{rug_path} set $key $val")) {
	    reportline (1, "Could not set var: $key");
            $error = 1;
        }
    }
    return !$error;
}

# NOTE: add_service fails if the service is already added, but we start
# rcd with --no-services so it's probably ok

sub add_service {
    my $self = shift;
    my @services = @_;
    foreach my $svc (@services) {
        reportline (2, "Running: $self->{rug_path} service-add $svc");
	if (run_cmd ("$self->{rug_path} service-add $svc")) {
	    reportline (1, "Could not add service \"$svc\"");
            return 0;
        }
    }
    return 1;
}

sub activate_key {
    my $self = shift;
    my ($svc, $key, $user) = @_;
    $user = "build-daemon\@ximian.com" unless $user;
    my $cmd = "$self->{rug_path} --no-refresh activate";

    reportline (2, "Running: $svc $key $user");
    if (run_cmd ("$cmd --service=$svc $key $user")) {
        reportline (1, "Could not activate key \"$key\"");
        return 0;
    }
    return 1;
}

sub subscribe {
    my $self = shift;
    my @channels = @_;
    my $error = 0;
    foreach my $ch (@channels) {
        reportline (2, "Running: $self->{rug_path} subscribe $ch");
	if (run_cmd ("$self->{rug_path} subscribe $ch")) {
	    reportline (1, "Could not subscribe to \"$ch\"");
            $error = 1;
        }
    }
    return !$error;
}

sub update_channel {
    my $self = shift;
    my @channels = @_;
    my $error = 0;
    foreach my $ch (@channels) {
        reportline (2, "Running: $self->{rug_path} update -y -r $ch");
	if (run_cmd ("$self->{rug_path} update -y -r $ch")) {
	    reportline (1, "Could not update \"$ch\"");
            $error = 1;
        }
    }
    return !$error;
}

# NOTE: Unfortunately, we can't check for errors here, because rug
# returns 1 (error) when the package is up-to-date during install

sub install {
    my $self = shift;
    my @pkgs = @_;

    return 1 unless scalar @pkgs;
    return 0 unless $self->ping; # At least check that rcd is up

    reportline (2, "Running: $self->{rug_path} install -r -V -y @pkgs");
    run_cmd ("$self->{rug_path} install -r -V -y @pkgs");
    return 1;
}

sub solvedeps {
    my $self = shift;
    my @deps = map { "'$_'" } @_;

    return 1 unless scalar @deps;

    reportline (2, "Running: $self->{rug_path} solvedeps -V -r -y @deps");
    if (run_cmd ("$self->{rug_path} solvedeps -V -r -y @deps")) {
	reportline (1, "Could not solvedeps.");
        return 0;
    }
    return 1;
}

########################################################################

sub print_channels {
    my $self = shift;
    reportline (2, "Running: $self->{rug_path} channels");
    return run_cmd ("$self->{rug_path} channels");
}

sub get_channels {
    my $self = shift;
    my $channels = {};
    reportline (2, "Running: $self->{rug_path} channels -t");
    my @raw_list = get_cmd_output ("$self->{rug_path} channels -t");
    foreach my $line (@raw_list) {
	chomp $line;
	my ($subd, $name, $desc) = split /\|/, $line;
	$subd = ($subd =~ /Yes/)? 1 : 0;
	$channels->{$name} = { description => $desc,
			       subscribed => $subd };
    }
    return $channels;
}

sub print_packages {
    my $self = shift;
    my $channels = join " ", @_;
    reportline (2, "Running: $self->{rug_path} packages $channels");
    return run_cmd ("$self->{rug_path} packages $channels");
}

sub get_packages {
    my $self = shift;
    my $channels = join " ", @_;
    reportline (2, "Running: $self->{rug_path} packages -t $channels");
    my @raw_list = get_cmd_output ("$self->{rug_path} packages -t $channels");
    my @ret;
    foreach my $line (@raw_list) {
	chomp $line;
	my ($status, $channel, $package, $version) = split /\|/, $line;
	unless ($version) {
	    # we only asked for one channel, so the output doesn't contain it
	    $version = $package;
	    $package = $channel;
	    $channel = $channels;
	}
	push @ret, { status => $status,
		     channel => $channel,
		     package => $package,
		     version => $version };
    }
    return \@ret;
}

sub print_preferences {
    my $self = shift;
    reportline (2, "Running: $self->{rug_path} get-prefs");
    return run_cmd ("$self->{rug_path} get-prefs");
}

sub get_preferences {
    my $self = shift;
    reportline (2, "Running: $self->{rug_path} get-prefs -t");
    my @raw_list = get_cmd_output ("$self->{rug_path} get-prefs -t");
    my $vars = {};
    my $desc = {};
    foreach my $line (@raw_list) {
	chomp $line;
	my ($name, $value, $description) = split /\|/, $line;
	$vars->{$name} = $value;
	$desc->{$name} = $description;
    }
    return ($vars, $desc);
}

sub print_services {
    my $self = shift;
    reportline (2, "Running: $self->{rug_path} service-list");
    return run_cmd ("$self->{rug_path} service-list");
}

sub get_services {
    my $self = shift;
    reportline (2, "Running: $self->{rug_path} service-list -t");
    my @raw_list = get_cmd_output ("$self->{rug_path} service-list -t");
    my $services = {};
    foreach my $line (@raw_list) {
	chomp $line;
	my ($index, $uri, $name) = split /\|/, $line;
	$services->{$index} = $uri;
    }
    return $services;
}

1;

__END__

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
