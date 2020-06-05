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

package CheckoutSource;

use strict;

use Ximian::Util ':all';
use Ximian::Run ':all';
use Ximian::BB::Macros ':all';

Ximian::BB::Plugin::register (name => "checkout",
                              group => "source",
                              clean => \&clean,
                              get => \&get,
                              apply_source => \&apply_source,
                              file_detect => \&detect,
                              snapshot_version => \&snapshot_version,
                              snapshot_serial => \&snapshot_serial);

########################################################################

sub clean {
    my ($handle, $conf, $args) = @_;

    if (my $file = detect ($handle, $conf)) {
        reportline (2, "Unlinking $file");
        unlink $file;
    }

    return 1;
}

sub get {
    my ($handle, $conf, $args) = @_;

    if (my $file = detect ($handle)) {
        if ($args->{keep_existing}) {
            reportline (2, "Using existing file \"$file\" for source \"$handle->{location}\"");
            return 1;
        } else {
            reportline (2, "Unlinking $file");
            unlink $file;
        }
    }

    my $cmd = macro_replace ($conf->{prepare}) . " && $ENV{MAKE} dist";
    $cmd =~ s%\./configure%\./autogen.sh%;
    $cmd = macro_replace ($handle->{dist}) if exists $handle->{dist};

    pushd macro_replace ($handle->{location});

    reportline (2, "Running: $cmd");
    if (run_cmd ($cmd)) {
	reportline (1, "Error running $cmd");
        popd;
        return 0;
    }
    popd;

    my $file = detect ($handle, $conf, {search => $handle->{location}});

    unless ($file) {
        reportline (1, "Checkout source: Could not find distribution tarball.");
        return 0;
    }
    if (run_cmd (macro_replace ("cp $handle->{location}/$file [[srcdir]]"))) {
        reportline (1, macro_replace ("cp $handle->{location}/$file [[srcdir]]"));
	reportline (1, "Checkout source: Could not move distribution tarball.");
        return 0;
    }
    return 1;
}

sub apply_source {
    my ($handle, $conf, $args) = @_;

    my $file = detect ($handle, $conf);
    unless ($file) {
        reportline (1, "Could not find file for source \"$handle\"");
        return 0;
    }
    report ({level=>2,tstamp=>1}, "Unpacking source: $file... ");

    pushd macro_replace ("[[builddir]]");
    my $srcdir = macro_replace ("[[srcdir]]");
    my $err = 1;
    if ($file =~ /(.*)\.tar$/) {
        $err = run_cmd ("cat $srcdir/$file | tar -xf -");
    } elsif ($file =~ /(.*)(\.tar\.gz|\.tgz)/) {
        $err = run_cmd ("gunzip -c $srcdir/$file | tar -xf -");
    } elsif ($file =~ /(.*)\.tar\.bz2/) {
        $err = run_cmd ("bunzip2 -c $srcdir/$file | tar -xf -");
    } elsif ($file =~ /(.*)\.zip/) {
        $err = run_cmd ("unzip $srcdir/$file");
    }
    popd;
    if ($err) {
        report (2, "error!\n\n");
        return 0;
    }
    report (2, "ok\n\n");
    return 1;
}

sub apply_patch {
    my ($handle, $conf, $args) = @_;
    reportline (1, "Patches of type 'checkout' are not supported");
    return 0;
}

sub detect {
    my ($handle, $conf, $args) = @_;
    my $glob = macro_replace ($handle->{distfile});
    pushd macro_replace ($args->{search} || "[[srcdir]]");
    my @tmp = glob $glob;
    popd;
    return "" unless @tmp;
    return $tmp[0];
}

########################################################################

sub snapshot_version {
    my ($handle, $conf) = @_;
    my $file = detect ($handle);

    unless ($file) {
        reportline (3, "Couldn't detect snapshot version: " .
                    "Could not find source file for \"$handle->{name}\"");
        return defined $conf->{version}? $conf->{version} : "";
    }

    my $version;
    foreach my $name (($conf->{srcname}, $conf->{name},
                       $conf->{package}->{default}->{name})) {
        my $n = macro_replace ($name);
        reportline (4, "Snapshot version search: \"^${n}[-_.](.*)[-_.](tar\.(gz|bz2)|tgz|zip)$\"");
        if ($file =~ /^${n}[-_.](.*)[-_.](tar\.(gz|bz2)|tgz|zip)$/) {
            $version = $1;
            reportline (3, "Snapshot version search: Detected \"$version\"");
            last;
        }
    }

    return ($version || $conf->{version});
}

sub snapshot_serial {
    my ($handle, $conf) = @_;
    my $timestamp;

    if (-d macro_replace ($handle->{location})) {
        pushd macro_replace ($handle->{location});
        my @svn_out = `svn info 2>&1`;
        unless ($? >> 8) {
            foreach (@svn_out) {
                if (m/^Revision: (.*)$/) {
                    $timestamp = "r$1";
                    my @mods = `svn status | egrep -v '^\\?' 2>&1`;
                    chomp @mods;
                    $timestamp .= "+mods" if scalar @mods;
                    reportline (3, "Snapshot serial: Using SVN revision \"$timestamp\"");
                    last;
                }
            }
        }
        popd;
    }

    return $timestamp if $timestamp;

    $timestamp = time;
    reportline (3, "Snapshot serial: Using timestamp \"$timestamp\"");
    return $timestamp;
}

1;
