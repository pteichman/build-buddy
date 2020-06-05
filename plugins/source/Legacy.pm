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

package LegacySource;

use strict;

use Ximian::Util ':all';
use Ximian::Run ':all';
use Ximian::BB::Conf ':all';
use Ximian::BB::Macros ':all';

Ximian::BB::Plugin::register (name => "legacy",
                              group => "source",
                              clean => \&clean,
                              get => \&get,
                              apply_source => \&apply_source,
                              apply_patch => \&apply_patch,
                              file_detect => \&detect,
                              snapshot_version => \&snapshot_version,
                              snapshot_serial => \&snapshot_serial);

########################################################################

sub clean {
    my ($handle, $conf, $args) = @_;
    my $ret = 1;

    pushd get_dir ("srcdir");
    if (my $file = detect ($handle, $conf)) {
        reportline (2, "Unlinking $file");
        $ret = unlink $file;
    }

    if ($handle =~ /^CVS/) {
        my ($nothing, $cvsroot, $module, $branch, $package) = split /\s/, $handle;
        if (-d "cvs/$module") {
            reportline (2, "Unlinking cvs/$module");
            $ret = !run_cmd "rm -rf cvs/$module";
        }
        unless (not -d "cvs" or dirgrep {/^[^.]/} "cvs") {
            reportline (2, "Unlinking cvs");
            $ret = rmdir "cvs";
        }
    } elsif ($handle =~ /^SVN /) {
        my ($nothing, $source) = split /\s/, $handle;
        $source =~ /\/([a-zA-Z-_]*)$/;
        my $module = $1;
        if (-d "svn/$module") {
            reportline (2, "Unlinking svn/$module");
            $ret = !run_cmd "rm -rf svn/$module";
        }
        unless (not -d "svn" or dirgrep {/^[^.]/} "svn") {
            reportline (2, "Unlinking svn");
            $ret = rmdir "svn";
        }
    }
    popd;
    return $ret;
}

########################################################################

sub get {
    my ($handle, $conf, $args) = @_;

    if ($args->{keep_existing}
        and my $file = detect ($handle, $conf)) {
        reportline (2, "Using existing file \"$file\" for source \"$handle\"");
        return 1;
    }

    pushd get_dir ("srcdir");

    my @info = split /\s/, $handle;
    my $ret;
    report (3, "Getting \"@info\"... ");
    if ($info[0] eq "CVS") {
        shift @info;
        $ret = get_cvs ($conf, $args, @info);
    } elsif ($info[0] eq "SVN") {
        shift @info;
        $ret = get_svn ($conf, @info);
    } elsif ($info[0] =~ /(HTTP|FTP)/) {
        shift @info;
        $ret = get_lwp (@info);
    } else {
        $ret = get_repo ($args, @info);
    }
    unless ($ret) {
        reportline (3, "failed");
        popd;
        return 0;
    }
    popd;
    reportline (3, "ok");
    return 1;
}

sub get_cvs {
    my ($conf, $args, @info) = @_;
    my ($cvsroot, $module, $branch, $package) = @info;
    my $is_tag = ($branch =~ /^\-t/);
    $branch =~ s/^\-t(.*)/$1/;

    mkdirs "cvs";
    pushd "cvs";

    run_cmd "rm -rf $module" if -d $module;

    my $cvscommand = "cvs -z3 -d $cvsroot co";
    $cvscommand .= " -D \"$args->{cvsdate}\"" if ($args->{cvsdate} && !$is_tag);
    $cvscommand .= " -r $branch" unless $branch eq "HEAD";
    $cvscommand .= " $module";
    $cvscommand = macro_replace ($cvscommand);

    reportline (2, "Running: $cvscommand");
    if (run_cmd ($cvscommand)) {
	reportline (1, "bb_unpack: error running $cvscommand");
        return 0;
    }

    # If we are checking out a directory inside a module, use only the
    # last directory

    if ($module =~ /(.+)\/([^\/]+)/) {
	run_cmd "mv $module .";
	run_cmd "rm -rf $1";
	$module = $2;
    }

    # Now do pre-autogen patches
    foreach my $patch (@{$conf->{cvspatch}->{i}}) {
	$patch =~ /^(\S+\.patch)-\d+$/;
	
	report (2, "applying patch:\t\t$1... ");
	
        my $patchcmd = ($ENV{PATCH} || "patch");
        $patchcmd .= " -p1 -d $module <[[srcdir]]/$1 >/dev/null";

	if (run_cmd (macro_replace ($patchcmd))) {
	    reportline (2, "patch failed!");
            popd;
            return 0;
        } else {
	    reportline (2, "ok");
	    if (run_cmd ("echo $patch >cvs-patched-to")) {
                reportline (1, "Warning: could not write cvs-patched-to file");
            }
        }
    }
	
    pushd $module;
	
    my $buildcommand;
    if (exists $conf->{dist}) {
	$buildcommand = macro_replace ($conf->{dist});
    } else {
	$buildcommand = macro_replace ($conf->{prepare});
        $buildcommand .= " && $ENV{MAKE} dist";
	$buildcommand =~ s%\./configure%\./autogen.sh%;
        $buildcommand = macro_replace ($buildcommand);
    }

    reportline (2, "Running: $buildcommand");
    if (run_cmd ($buildcommand)) {
	reportline (1, "Error running $buildcommand");
        popd; popd;
        return 0;
    }

    my $file = detect ("CVS @info", $conf, 1);
    popd;
    popd;

    unless ($file) {
        reportline (1, "CVS: Could not find distribution tarball.  Exiting.");
        return 0;
    }
    if (run_cmd (macro_replace ("cp cvs/$module/$file [[srcdir]]"))) {
	reportline (1, "Could not move distribution tarball.  Exiting.");
        return 0;
    }
    return 1;
}

sub get_svn {
    my ($conf, @info) = @_;

    mkdirs "svn";
    pushd "svn";

    reportline (2, "Running: \"svn co @info\"");
    my $svncommand = "svn co @info";
    $svncommand = macro_replace ($svncommand);
    if (run_cmd ($svncommand)) {
        reportline (1, "Error: Could not run svn command.");
        return 0;
    }

    my @dirs = dirgrep { /^[^.]/ and -d $_ } ".";
    die "Error: No directories were checked out by svn." unless @dirs;
    my $dir = shift @dirs;
    reportline (2, "Using module directory \"$dir\"");
    pushd $dir;

    my $buildcommand;
    if (exists $conf->{dist}) {
        $buildcommand = macro_replace ($conf->{dist});
    } else {
	$buildcommand = macro_replace ($conf->{prepare});
        $buildcommand .= " && $ENV{MAKE} dist";
        $buildcommand =~ s%\./configure%\./autogen.sh%;
        $buildcommand = macro_replace ($buildcommand);
    }

    if (run_cmd ($buildcommand)) {
        reportline (1, "SVN: error running \"$buildcommand\"");
        return 0;
    }

    my $file = detect ("SVN @info", $conf, 1);
    popd;
    popd;

    unless ($file) {
        reportline (1, "SVN: Could not find distribution tarball.  Exiting.");
        return 0;
    }
    if (run_cmd (macro_replace ("cp svn/$dir/$file [[srcdir]]"))) {
        reportline (1, "Could not move distribution tarball.  Exiting.");
        return 0;
    }
    return 1;
}

sub get_lwp {
    my (@info) = @_;

    eval { require LWP::UserAgent; };
    if ($@) { die "bb_get_lwp requires LWP!"; }

    my $url = (shift @info || '');
    return 0 unless $url;

    $url =~ /^(.+?):\/\/(.+)\/(.+)$/;
    my $proto = $1;
    my $file = $3;

    my $ua = LWP::UserAgent->new ('timeout' => 30,);
    unless ($ua->is_protocol_supported($proto)) {
	reportline (1, "LWP: Protocol for $proto is not supported.");
        return 0;
    }

    unless ($proto) {
        reportline (1, "LWP: I think your URL ($url) was malformed");
        return 0;
    }

    my $response = $ua->get ($url, 
                             ':content_file' => macro_replace ("[[srcdir]]/$file"));
    unless ($response->is_success) {
	reportline (1, "LWP: Failed to get $response->request->uri:",
                $response->status_line, "Aborting");
        return 0;
    }

    chmod 0664, macro_replace ("[[srcdir]]/$file");
    return 1;
}

sub get_repo {
    my ($args, $handle) = @_;
    $handle =~ /^(\S+)-\d+$/;
    my $file = $1;

    unless ($file) {
        reportline (1, "handle must be of form foo-1");
        return 0;
    }

    my $cache = get_dir ("localcache");
    my $dest = get_dir ("srcdir");
    my $cmd = "cp $cache/$handle/$file $dest/$file";
    unless (-e "$cache/$handle/$file") {
        $cmd = get_dir ("bb_exec") . "/bb_scp ";
        if (macro_replace ("[[repohost]]")) {
            $cmd .= "-P [[repoport]] " if macro_replace ("[[repoport]]");
            if (macro_replace ("[[repouser]]")) {
                $cmd .= "[[repouser]]@[[repohost]]:";
            } else {
                $cmd .= "[[repohost]]:";
            }
        }
        $cmd .= "[[repodir]]/$handle/$file ";
        $cmd .= "$dest/$file >/dev/null";
        $cmd = macro_replace ($cmd);
    }
    reportline (3, "Running: \"$cmd\"");
    if (run_cmd ($cmd)) {
        reportline (1, "Error getting \"$handle\" from the repository.");
        return 0;
    }

    chmod 0664, "$dest/$file";

    unless (-e "$cache/$handle/$file") {
        reportline (3, "Copying \"$handle\" to the local cache.");
        eval {
            mkdirs "$cache/$handle";
            copy ("$dest/$file", "$cache/$handle/$file");
        };
        if (my $e = $@) {
            reportline (3, "Warning: could not copy source to repository cache: $!");
        }
    }

    return 1;
}

########################################################################

sub apply_source {
    my ($handle, $conf) = @_;

    my $file = detect ($handle, $conf);
    unless ($file) {
        reportline (1, "Could not find file for source \"$handle\"");
        return 0;
    }

    report ({level=>2,tstamp=>1}, "Unpacking source: $file... ");

    pushd get_dir ("builddir");

    my $err = 1;
    my $srcdir = get_dir ("srcdir");
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
    $handle =~ /^(\S+\.patch)-\d+$/;
    my $patch = $1;

    my $srcdir = get_dir ("srcdir");
    pushd get_dir ("builddir");
 
    unless ($patch and -f "$srcdir/$patch") {
        reportline (1, "Error: can't open patch for \"$handle\"");
        return 0;
    }
    reportline ({level=>2,nline=>0}, "Applying patch: $patch... ");

    if (exists $conf->{tardir}) {
        reportline (4, "Tardir set in the conf, replacing macros.");
        $conf->{tardir} = macro_replace ($conf->{tardir});
    } else {
        foreach my $name (("$conf->{srcname}-$conf->{version}",
                           $conf->{srcname}, $conf->{name}, "")) {
            $name = macro_replace ($name);
            my @srcglob = glob "$name*";
            reportline (4, "Tardir search \"$name*\" found: \"@srcglob\"");
            if (@srcglob and -d $srcglob[0]) {
                $conf->{tardir} = $srcglob[0];
                last;
            }
        }
    }

    unless ($conf->{tardir} and -d $conf->{tardir}) {
        reportline (1, "Could not find unpacked source.");
        popd;
        return 0;
    }
    reportline (3, "Using tardir \"$conf->{tardir}\"");

    my $cmd = ($ENV{PATCH} || "patch");
    my $ret = run_cmd ("$cmd -p1 -d $conf->{tardir} < $srcdir/$patch > /dev/null");
    run_cmd ("echo $patch >$srcdir/patched-to");
    popd;

    if ($ret > 0) {
        reportline (2, "patch failed!");
        return 0;
    }
    report (2, "ok\n\n");
    return 1;
}

########################################################################

sub detect {
    my ($handle, $conf, $use_cwd) = @_;

    $handle = macro_replace ($handle);
    pushd get_dir ("srcdir") unless $use_cwd;

    my $ret;
    if ($handle =~ /^CVS /) {
        my ($nothing, $cvsroot, $module, $branch, $package) = split /\s/, $handle;
        $package = ($package || $module);
        my @tmp;
        if (@tmp = glob "$package-$conf->{version}*.tar.{gz,bz2}") {
            $ret = $tmp[0];
        } elsif (@tmp = glob "$package*.tar.{gz,bz2}") {
            $ret = $tmp[0];
        } elsif (@tmp = glob "@{[macro_replace ($conf->{srcname})]}*.tar.{gz,bz2}") {
            $ret = $tmp[0];
        }
    } elsif ($handle =~ /^SVN /) {
        my ($nothing, $source) = split /\s/, $handle;
        $source =~ /\/([a-zA-Z-_]*)$/;
        my $module = $1;
        my @tmp;
        if (@tmp = glob "$module-$conf->{version}*.tar.{gz,bz2}") {
            $ret = $tmp[0];
        } elsif (@tmp = glob "$module*.tar.{gz,bz2}") {
            $ret = $tmp[0];
        } elsif (@tmp = glob "@{[macro_replace ($conf->{srcname})]}*.tar.{gz,bz2}") {
            $ret = $tmp[0];
        }
    } elsif ($handle =~ /^(HTTP|FTP) /) {
        # These lines look like
        # FTP ftp://foo/bar/foobar-0.1-tar.gz
        $handle =~ /^(.+?):\/\/(.+)\/(.+)$/;
        $ret = $3 if -e $3;
    } else {
        $handle =~ /^(.*)-\d+$/;
        $ret = $1 if -e $1;
    }
    popd unless $use_cwd;
    reportline (3, "Could not find source for \"$handle\"") unless $ret and -e $ret;
    return $ret;
}

sub snapshot_version {
    my ($handle, $conf) = @_;
    my $file = detect ($handle, $conf);

    unless ($file) {
        report (1, "Couldn't detect snapshot version: " .
                "Could not find source file for \"$handle\"");
        return $conf->{version};
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

    pushd get_dir ("srcdir");

    my @svnglob = glob "svn/*";
    if ($handle =~ /^SVN/ and @svnglob and -d $svnglob[0]) {
        pushd "svn/$svnglob[0]";
        my @svn_out = `svn info 2>&1`;
        unless ($? >> 8) {
            foreach (@svn_out) {
                if (m/^Revision: (.*)$/) {
                    $timestamp = $1;
                    reportline (3, "Snapshot serial: Using SVN revision \"$timestamp\"");
                    last;
                }
            }
        }
        popd;
    }
    popd;

    return $timestamp if $timestamp;

    $timestamp = time;
    reportline (3, "Snapshot serial: Using timestamp \"$timestamp\"");
    return $timestamp;
}

1;
