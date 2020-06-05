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

package Ximian::BB::Module;

use strict;
use Carp;

use Ximian::Util ':all';
use Ximian::BB::Globals;
use Ximian::BB::Conf ':all';
use Ximian::BB::Macros ':all';

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
		  package_names
		  source_files
		  package_file
		  module_files
		  package_file_version
		  package_installed_version
                  is_package_installed
		  is_module_installed
                  find_handler
                  source_file
                  snapshot_version
                  snapshot_serial
                  make_version
                  make_rev
                  full_version
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

sub package_names {
    my ($conf) = @_;
    my @ret;
    foreach my $pkg (values %{$conf->{package}}) {
	next unless keys %$pkg;
	push @ret, $pkg->{name};
    }
    return @ret;
}

sub source_files {
    my ($conf, $fulltarget) = @_;
    my $packsys = $Ximian::BB::Globals::packsys;
    ($packsys) = split ':', $fulltarget if $fulltarget;

    my @ret;
    my $srcname = ($conf->{srcname} || $conf->{name});
    my $rev = make_rev ($conf);

    if ($packsys eq "dpkg") {
	my $base = "${srcname}_$conf->{version}";
	push @ret, "$base\.orig.tar.gz";
	push @ret, "$base\-$rev.diff.gz";
	push @ret, "$base\-$rev.dsc";
    } elsif ($packsys eq "rpm") {
	push @ret, "$srcname-$conf->{version}-$rev.src.rpm";
    }

    return @ret;
}

sub package_file {
    my ($conf, $package, $fulltarget) = @_;
    my $packsys = $Ximian::BB::Globals::packsys;
    my $target = $Ximian::BB::Globals::target;
    ($packsys, $target) = split ':', $fulltarget if $fulltarget;
    my (undef, undef, $arch) = split '-', $target;

    my $version = $conf->{version};
    my $release = make_rev ($conf);
    $arch = $conf->{psdata}->{architecture}
        if exists $conf->{psdata}->{architecture};

    foreach my $pkg (values %{$conf->{package}}) {
	next unless keys %$pkg and $pkg->{name} eq $package;
        if (exists $pkg->{psdata}->{architecture}
            and $pkg->{psdata}->{architecture} ne "any") {
            $arch = $pkg->{psdata}->{architecture};
        }
    }

    return "$package\_$version-$release\_$arch.deb" if ($packsys eq "dpkg");
    return "$package-$version-$release.$arch.rpm" if ($packsys eq "rpm");
    return undef;
}

sub module_files {
    my ($conf, $include_source, $fulltarget) = @_;
    my $packsys = $Ximian::BB::Globals::packsys;
    my $target = $Ximian::BB::Globals::target;
    ($packsys, $target) = split ':', $fulltarget if $fulltarget;
    my @ret;

    if ($packsys eq "sd") {
	my $revision = make_rev ($conf);
	push @ret, "$conf->{name}-$conf->{version}.$revision.depot";
    } else {
        foreach (package_names ($conf)) {
            push @ret, package_file ($conf, $_, "$packsys:$target");
        }
	push @ret, source_files ($conf) if $include_source;
    }
    return @ret;
}

######################################################################

sub package_file_version {
    my ($filename) = @_;
    my ($version, $rev, $epoch);
    my $packsys = $Ximian::BB::Globals::packsys;

    if ($packsys eq "rpm") {
	my $cmd = "";
	chomp (my $line = `rpm -qp $filename --queryformat=\"%{VERSION} %{RELEASE} %{EPOCH}\"`);
	($version, $rev, $epoch) = split /\s+/, $line;
	$epoch =~ s/\(none\)//;
    } elsif ($packsys eq "dpkg") {
	my $line = `dpkg --info $filename | grep Version\:`;
	chomp $line;
	$line =~ /Version\: (.*)/;
	my $verstring = $1;
	$verstring =~ /(.*)-(.*)/;
	$epoch = "";
	($version, $rev) = ($1, $2);
	if ($version =~ /(.*)*?:(.*)/) {
	    $epoch = $1;
	    $version = $2;
	}
    } elsif ($packsys eq "sd") {
	# FIXME: This method doesn't work for sd yet.
	print STDERR "fixme: get_package_version not yet implemented for sd.";
	my $line = `/usr/sbin/swlist -l product -a revision $filename | grep $filename | awk "{ print \(\\\$2\) }"`;
	$version = $line;
	$rev = "";
	$epoch = "";
    }
    chomp $version;
    chomp $rev;
    chomp $epoch;
    return ($version, $rev, $epoch);
}

sub package_installed_version {
    my ($package) = @_;
    my ($version, $rev, $epoch);
    my $packsys = $Ximian::BB::Globals::packsys;

    if ($packsys eq "rpm") {
	my $cmd = "";
	chomp (my $line = `rpm -q $package --queryformat=\"%{VERSION} %{RELEASE} %{EPOCH}\"`);
	($version, $rev, $epoch) = split /\s+/, $line;
	$epoch =~ s/\(none\)//;
    } elsif ($packsys eq "dpkg") {
	my $line = `dpkg -s $package | grep Version\:`;
	chomp $line;
	$line =~ /Version\: (.*)/;
	my $verstring = $1;
	$verstring =~ /(.*)-(.*)/;
	$epoch = "";
	($version, $rev) = ($1, $2);
	if ($version =~ /(.*)*?:(.*)/) {
	    $epoch = $1;
	    $version = $2;
	}
    } elsif ($packsys eq "sd") {
	my $line = `/usr/sbin/swlist -l product -a revision $package | grep $package | awk "{ print \(\\\$2\) }"`;
	$version = $line;
	$rev = "";
	$epoch = "";
    }
    chomp $version;
    chomp $rev;
    chomp $epoch;
    return ($version, $rev, $epoch);
}

######################################################################

sub is_package_installed {
    my ($package) = @_;
    my $packsys = $Ximian::BB::Globals::packsys;

    my $ret = 0;
    if ($packsys eq "rpm") {
	$ret = (system ("rpm -q $package > /dev/null") == 0) ? 1 : 0;
    } elsif ($packsys eq "dpkg") {
	$package =~ s/\+/\\+/;
	open STATUS, "/var/lib/dpkg/status";
	while (<STATUS>) {
	    if (/Package\: $package/) {
		$_ = <STATUS>;
		if (/installed/) {
		    $ret = 1;
		} else {
		    $ret = 0;
		}
		last;
	    }
	}
	close STATUS;
    }
	
}

sub is_module_installed {
    my ($conf) = @_;
    my $packsys = $Ximian::BB::Globals::packsys;

    if ($packsys eq "sd") {
	my $package = $conf->{build}->{default}->{name};
	my ($version, $rev, $epoch) = get_installed_version ($package);
	my $ver = "$conf->{version}." . make_rev ($conf);

	if ($version eq $ver) {
	    return 1;
	} else {
	    return 0;
	}
    } else {
	foreach my $package (package_names ($conf)) {
	    if (!is_package_installed ($package)) {
		return 0;
	    }
	    
	    my ($version, $rev, $epoch) = get_installed_version ($package);
	    if (!($version eq $conf->{version}) or
		!($rev eq make_rev ($conf))) {
		return 0;
	    }
	    if (exists $conf->{epoch} and !($epoch eq $conf->{epoch})) {
		return 0;
	    }
	    if (!(exists $conf->{epoch}) and !($epoch eq "")) {
		return 0;
	    }
	    
	}
	return 1;
    }
}

######################################################################

sub find_handler {
    my ($handle, $op, $handlers) = @_;

    # Legacy source lines
    unless (ref $handle) {
        my $handler = $handlers->{legacy};
        unless (exists $handler->{$op}) {
            reportline (1, "Could not find handler for source \"$handle\"");
            return "";
        }
        return $handler->{$op};
    }

    my $handler;
    if (exists $handle->{type}
        and exists $handlers->{$handle->{type}}
        and exists $handlers->{$handle->{type}}->{$op}) {
        $handler = $handlers->{$handle->{type}}->{$op};
    }
    unless ($handler) {
        reportline (1, "Could not find handler for source \"$handle->{name}\"");
        return "";
    }
    return $handler;
}

######################################################################

sub source_file {
    my ($handle, $conf, $handlers) = @_;
    my $handler = find_handler ($handle, "file_detect", $handlers);
    return "" unless $handler;
    return $handler->($handle, $conf);
}

sub snapshot_version {
    my ($conf, $handlers) = @_;
    my $handle = $conf->{source}->{i}->[0];
    return "" unless $handle;
    my $handler = find_handler ($handle, "snapshot_version", $handlers);
    return "" unless $handler;
    return $handler->($handle, $conf);
}

sub snapshot_serial {
    my ($conf, $handlers) = @_;
    my $handle = $conf->{source}->{i}->[0];
    return "" unless $handle;
    my $handler = find_handler ($handle, "snapshot_serial", $handlers);
    return "" unless $handler;
    return $handler->($handle, $conf);
}

######################################################################

sub make_version {
    my ($conf, $source_handlers) = @_;
    my $version;
    # the hash check is because of how XML::Simple parses <foo/>
    if ($conf->{version} and not ishash $conf->{version}) {
        $version = $conf->{version};
    } elsif ($conf->{snapshot}) {
        $version = snapshot_version ($conf, $source_handlers);
    }
    $version = ($version || "");
    reportline (3, "Version: $version");
    return $version;
}

sub make_rev {
    my ($conf, $source_handlers) = @_;

    return $conf->{revision} if defined $conf->{revision};

    my $rev = defined $conf->{rev}?
        $conf->{rev} : (macro_replace ("[[rev]]") || 0);
    my $serial = defined $conf->{serial}?
        $conf->{serial} : (macro_replace ("[[serial]]") || 0);
    my $os_serial = (macro_replace ("[[os_serial]]") || 0);
    my $shortname = macro_replace ("[[shortname]]");

    reportline (3, "Rev: $rev");
    reportline (3, "Serial: $serial");
    reportline (3, "OS serial: $os_serial");
    reportline (3, "Shortname: $shortname");

    my $revision = $rev;
    $revision .= ".$shortname" if $shortname;
    $revision .= ".$os_serial.$serial";
    if ($conf->{snapshot}) {
        $revision .= "." . (snapshot_serial ($conf, $source_handlers) || 0);
    }

    return $revision;
}

######################################################################

sub full_version {
    my ($conf, $target) = @_;
    my $packsys = $Ximian::BB::Globals::packsys;
    if ($target) {
        ($packsys, undef) = split ':', $target;
    }
    if ($packsys eq 'rpm') {
	return full_version_rpm ($conf);
    } elsif ($packsys eq 'dpkg') {
	return full_version_dpkg ($conf);
    } elsif ($packsys eq 'sd') {
	return full_version_sd ($conf);
    } elsif ($packsys eq 'inst') {
        return full_version_inst ($conf);
    }
    croak "Could not determine package version.";
}

sub full_version_rpm {
    my ($conf) = @_;
    my $v = "$conf->{version}-$conf->{revision}";
    $v = "$conf->{epoch}:$v" if defined $conf->{epoch};
    return $v;
}

sub full_version_dpkg {
    my ($conf) = @_;
    my $v = "$conf->{version}-$conf->{revision}";
    $v = "$conf->{epoch}:$v" if defined $conf->{epoch};
    return $v;
}

sub full_version_sd {
    my ($conf) = @_;
    my $v = "$conf->{version}.$conf->{revision}";
#    $v = "$conf->{epoch}.$v" if defined $conf->{epoch};
    return $v;
}

sub full_version_inst {
    my ($conf) = @_;
    my $instversion = $conf->{psdata}->{inst_version}->{cdata};
    die "No instversion supplied in conf file." unless $instversion;
    return $instversion . ($conf->{rev} ? $conf->{rev} : "00") .
	($conf->{serial} ? $conf->{serial} : "0");
}

1;
