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

package Ximian::BB::Jail::RCD;

=head1 NAME

B<Ximian::BB::Jail::RCD> - Object to interact with RCD in a jail

=head1 DESCRIPTION



=head1 SYNOPSIS

    ...

=cut

use strict;

use base 'Ximian::BB::Jail::Serializable';

use Ximian::Util ':all';
use Ximian::Run ':all';

########################################################################

=head1 CLASS METHODS

=head2 new (option => value, ...)

See C<Ximian::BB::Jail::Serializable> for more options (including
required ones!).

=head2 load (key => value, ...)

=cut

sub new {
    my $class = shift;
    die "Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    my $self = bless {}, $class;
    $self->SUPER::new (@_);
    $self->{metadata} = $self->{jail}->get_or_new_metadata ("rcd");
    $self->{session} = ($opts->{session} ||
			Ximian::BB::Jail::Session->new (jail => $self->{jail}));
    $self->set_mcookie ($opts->{rcd_mcookie}) if $opts->{rcd_mcookie};
    $self->set_partnernet ($opts->{rcd_partnernet}) if $opts->{rcd_partnernet};
    return $self;
}

sub load {
    my $class = shift;
    die "Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    my $tmp = bless {}, $class;
    my $self = $tmp->SUPER::load (@_); # SUPER::load returns a new object
    $self->{metadata} = $self->{jail}->get_or_new_metadata ("rcd");
    $self->{session} = $self->{jail}->get_object ($self->{session_id});
    $self->set_mcookie ($opts->{rcd_mcookie}) if $opts->{rcd_mcookie};
    $self->set_partnernet ($opts->{rcd_partnernet}) if $opts->{rcd_partnernet};
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
    $clone->{session_id} = $clone->{session}->get_object_id;
    delete $clone->{session};
    delete $clone->{metadata};
}

sub new_object_id {
    my $self = shift;
    return "rcd";
}

########################################################################

sub start_daemon {
    my $self = shift;
    my $jail_path = $self->{jail}->jail_path; # Dir-type only!
    my $tree = $self->{metadata}->get_xml_tree;
    my $rcd = ($tree->{rcd_path} || "/usr/sbin/rcd");
    my $rcd_data = ($tree->{rcd_data_dir} || "/var/lib/rcd");
    my $conf_path = ($tree->{rcd_conf_path} || "/etc/ximian");
    my $rcd_conf = ($tree->{rcd_conf}->{i} || undef);
    my $rcd_pass = ($tree->{rcd_passwd}->{i} ||
		    ["distro::view,install,remove,upgrade,subscribe"]);
    chomp @$rcd_conf;
    chomp @$rcd_pass;

    my $dir = "$jail_path/$conf_path";
    mkdirs $dir;

    # Write out mcookie/partnernet if we have those in the metadata
    foreach my $file (qw/mcookie partnernet/) {
	next unless exists $tree->{"rcd_$file"};
	open FILE, ">$dir/$file" or die "Could not open $dir/$file: $!\n";
	print FILE $tree->{"rcd_$file"};
	close FILE;
    }

    # Write out the password + options files
    open FILE, ">$dir/rcd.passwd" or die "Could not open $dir/rcd.passwd: $!\n";
    print FILE "$_\n" foreach (@$rcd_pass);
    close FILE;

    open FILE, ">$dir/rcd.conf" or die "Could not open $dir/rcd.conf: $!\n";
    print FILE "$_\n" foreach (@$rcd_conf);
    close FILE;

    # Cache can cause problems (though rarely)
    $self->{session}->run_cmd ({name => "rcd:cleanup"}, "rm -rf $rcd_data");

    # start rcd
    $self->{session}->run_cmd ({name => "rcd:start"}, "$rcd -r --no-services")
	&& die "Could not run $rcd";

    # ...and make sure it's running
    my $slept;
    my $done;
    until ($done) {
	eval {
	    $self->ping (no_server_start => 1);
	    $done = 1;
	};
	# We can't use SIGALRM:
	safe_sleep (5 * ++$slept);
        die "Error starting rcd." if ($slept >= 60/5);
    }
    return 1;
}

########################################################################

sub get_mcookie {
    my $self = shift;
    my $tree = $self->{metadata}->get_xml_tree;
    return $tree->{rcd_mcookie};
}

sub get_partnernet {
    my $self = shift;
    my $tree = $self->{metadata}->get_xml_tree;
    return $tree->{rcd_partnernet};
}

sub set_mcookie {
    my $self = shift;
    my $tree = $self->{metadata}->get_xml_tree;
    $tree->{rcd_mcookie} = shift;
    $self->shutdown;
}

sub set_partnernet {
    my $self = shift;
    my $tree = $self->{metadata}->get_xml_tree;
    $tree->{rcd_partnernet} = shift;
    $self->shutdown;
}

########################################################################

# we do this in every function:
sub _get_rug {
    my $self = shift;
    my %opts = @_;
    my $tree = $self->{metadata}->get_xml_tree;
    my $rug = ($tree->{rug_path} || "/usr/bin/rug");

    unless ($opts{no_server_start}) {
	# ok, this is pretty lame, but I don't want this one
	# command logged every time we use rug.  call me stupid.
	local $self->{session}->{logging_cb} = sub { };
	if ($self->{session}->run_cmd ("$rug ping")) {
	    $self->start_daemon;
	}
    }
    return $rug;
}

########################################################################

sub ping {
    my $self = shift;
    my %opts = @_;
    my $rug = $self->_get_rug (no_server_start => $opts{no_server_start});

    my $run_opts = {name => ($opts{name} || "rug:ping")};
    $self->{session}->run_cmd ($run_opts, "$rug ping")
	&& die "Could not ping rcd daemon";

    return 1;
}

sub restart {
    my $self = shift;
    my %opts = @_;
    my $rug = $self->_get_rug;

    my $run_opts = {name => ($opts{name} || "rug:restart")};
    $self->{session}->run_cmd ($run_opts, "$rug restart")
	&& die "Could not restart rcd daemon";

    return 1;
}

sub shutdown {
    my $self = shift;
    my %opts = @_;
    my $rug = $self->_get_rug;

    my $run_opts = {name => ($opts{name} || "rug:shutdown")};
    $self->{session}->run_cmd ($run_opts, "$rug shutdown")
	&& die "Could not shutdown rcd daemon";

    return 1;
}

sub refresh {
    my $self = shift;
    my %opts = @_;
    my $rug = $self->_get_rug;

    my $run_opts = {name => ($opts{name} || "rug:refresh")};
    $self->{session}->run_cmd ($run_opts, "$rug refresh")
	&& die "Could not refresh rcd daemon";
    return 1;
}

########################################################################

sub set_var {
    my $self = shift;
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my %settings = @_;
    my $rug = $self->_get_rug;

    while (my ($key, $val) = each %settings) {
	my $run_opts = {name => ($opts{name} || "rug:set:$key")};
	$self->{session}->run_cmd ($run_opts, "$rug set $key $val")
	    && die "Could not set var: $key";
    }
    $self->refresh;

    return 1;
}

# NOTE: add_service fails if the service is already added, but we start
# rcd with --no-services so it's probably ok

sub add_service {
    my $self = shift;
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my @services = @_;
    my $rug = $self->_get_rug;

    my $c = 0;
    foreach my $svc (@services) {
	$c++;
	my $run_opts = {name => ($opts{name} || "rug:service-add:$c")};
	$self->{session}->run_cmd ($run_opts, "$rug service-add $svc")
	    && die "Could not add service \"$svc\"";
    }
    return 1;
}

sub activate_key {
    my $self = shift;
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my %act = @_;
    my $rug = $self->_get_rug;

    my $ref = $opts{no_refresh}? "--no-refresh" : "";
    my $run_opts = {name => ($opts{name} ||
			     "rug:activate:$act{user}:$act{key}")};
    my $cmd = "$rug $ref activate --service=$act{url} $act{key} $act{user}";
    $self->{session}->run_cmd ($run_opts, $cmd)
	    && die "Could not activate key \"$act{key}\"";
    return 1;
}

sub subscribe_channel {
    my $self = shift;
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my @channels = @_;
    my $rug = $self->_get_rug;

    foreach my $ch (@channels) {
	my $run_opts = {name => ($opts{name} || "rug:subscribe:$ch")};
	$self->{session}->run_cmd ($run_opts, "$rug sub $ch")
	    && die "Could not subscribe to \"$ch\"";
    }
    return 1;
}

sub update_channel {
    my $self = shift;
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my @channels = @_;
    my $rug = $self->_get_rug;

    foreach my $ch (@channels) {
	my $run_opts = {name => ($opts{name} || "rug:update:$ch")};
	$self->{session}->run_cmd ($run_opts, "$rug up -y -r $ch")
	    && die "Could not update \"$ch\"";
    }
    return 1;
}

sub install {
    my $self = shift;
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my @pkgs = @_;
    my $rug = $self->_get_rug;
    my $run_opts = {name => ($opts{name} || "rug:install")};

    return 1 unless scalar @pkgs;

    # Unfortunately, we can't check for errors here, because rc
    # returns 1 (error) when the package is up-to-date during an
    # rc in.

    $self->{session}->run_cmd ($run_opts, "$rug in -r -V -y @pkgs");
    return 1;
}

sub solvedeps {
    my $self = shift;
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my @deps = map { "'$_'" } @_;
    my $rug = $self->_get_rug;
    my $run_opts = {name => ($opts{name} || "rug:solvedeps")};

    return 1 unless scalar @deps;

    $self->{session}->run_cmd ($run_opts, "$rug solvedeps -r -y @deps")
	&& die "Could not solvedeps.";
    return 1;
}

########################################################################

sub print_channels {
    my $self = shift;
    my %opts = @_;
    my $rug = $self->_get_rug;

    my $run_opts = {name => ($opts{name} || "rug:info:channels")};
    return $self->{session}->run_cmd ($run_opts, "$rug channels");
}

sub get_channels {
    my $self = shift;
    my %opts = @_;
    my $rug = $self->_get_rug;

    my $run_opts = {name => ($opts{name} || "rug:info:channels")};
    my @raw_list = $self->{session}->get_cmd_output ($run_opts,
						     "$rug channels -t");

    my $channels = {};
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
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my $channels = join " ", @_;
    my $rug = $self->_get_rug;

    my $run_opts = {name => ($opts{name} || "rug:info:packages")};
    return $self->{session}->run_cmd ($run_opts, "$rug packages $channels");
}

sub get_packages {
    my $self = shift;
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my $channels = join " ", @_;
    my $rug = $self->_get_rug;

    my $run_opts = {name => ($opts{name} || "rug:info:packages")};
    my @raw_list = $self->{session}->get_cmd_output
	($run_opts, "$rug packages -t $channels");

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
    my %opts = @_;
    my $rug = $self->_get_rug;

    my $run_opts = {name => ($opts{name} || "rug:info:preferences")};
    return $self->{session}->run_cmd ($run_opts, "$rug get-prefs");
}

sub get_preferences {
    my $self = shift;
    my %opts = @_;
    my $rug = $self->_get_rug;

    my $run_opts = {name => ($opts{name} || "rug:info:preferences")};
    my @raw_list = $self->{session}->get_cmd_output ($run_opts,
						     "$rug get-prefs -t");

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
    my %opts = @_;
    my $rug = $self->_get_rug;

    my $run_opts = {name => ($opts{name} || "rug:info:services")};
    return $self->{session}->run_cmd ($run_opts, "$rug service-list");
}

sub get_services {
    my $self = shift;
    my %opts = @_;
    my $rug = $self->_get_rug;

    my $run_opts = {name => ($opts{name} || "rug:info:services")};
    my @raw_list = $self->{session}->get_cmd_output ($run_opts,
						     "$rug service-list -t");

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
