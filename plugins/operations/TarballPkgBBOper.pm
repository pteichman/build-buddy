# Copyright 2004 Ximian, Inc.
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

# $Id: TarballPkgBBOper.pm 3080 2006-01-05 01:10:21Z v_thunder $

#------------------------------------------------------------------------------

package TarPackage;

use RPC::XML::Client;

use Ximian::Run ':all';
use Ximian::Util ':all';
use Ximian::BB::Conf ':all';

Ximian::BB::Plugin::register
    (name => "tar-package",
     group => "operations",
     operations =>
     [
      { name => "tarpkg:create",
        module => \&pkg_create,
        description => "Create tar-based 'packages', generally for re-packaging elsewhere" },
      { name => "tarpkg:unpack",
        module => \&pkg_unpack,
        description => "Unpack tar-based 'packages' created with tarpkg:create for repackaging" },
      { name => "tarpkg:get",
        module => \&pkg_get,
        description => "Download tar-based 'packages' from a remote node, for repackaging on this one" },
      ]);

my %args;
parse_args (\%args,
	    [
	     {names => ["tarpkg_get_nodeid"], type => "=s", default => ""},
	    ]);

#------------------------------------------------------------------------------

sub pkg_create {
    my ($module, $data) = @_;
    my $conf = $module->{conf};

    my $topdir = get_dir ("topdir");
    my $pkgname = "$module->{name}-$conf->{version}-$conf->{revision}.tar.gz";
    my $link = "$module->{name}.tar.gz";

    mkdirs $data->{archivedir};

    unless (-d $topdir) {
        reportline (1, "tarpkg:create: topdir does not exist: $topdir");
        return 1;
    }

    pushd $topdir;
    if (run_cmd ("tar czf $data->{archivedir}/$pkgname *")) {
        reportline (1, "tarpkg:create: Could not create package tarball.");
        popd;
        return 1;
    }
    run_cmd ("ln -sf $pkgname $data->{archivedir}/$link");
    reportline (2, "tarpkg:create: Successfully created $data->{archivedir}/$pkgname");
    popd;

    return 0;
}

sub pkg_unpack {
    my ($module, $data) = @_;
    my $conf = $module->{conf};

    my $topdir = get_dir ("topdir");
    my $pkgname;

    foreach my $file (("$module->{name}-$conf->{version}-$conf->{revision}.tar.gz",
                       "$module->{name}-$conf->{version}.tar.gz",
                       "$module->{name}.tar.gz")) {
        reportline (4, "tarpkg:unpack: Trying package filename \"$file\"...");
        $pkgname = "$data->{archivedir}/$file" if -f "$data->{archivedir}/$file";
    }
    unless ($pkgname) {
        reportline (1, "tarpkg:unpack: Could not find package tarball in archivedir.");
        return 1;
    }
    reportline (4, "tarpkg:unpack: Using package filename \"$pkgname\"...");

    if (-d $topdir) {
        reportline (2, "tarpkg:unpack: Topdir already exists, cleaning up...");
        run_cmd ("rm -rf $topdir");
    }

    mkdirs $topdir;
    pushd $topdir;
    if (run_cmd ("tar xzf $pkgname")) {
        reportline (1, "tarpkg:unpack: Could not unpack package tarball.");
        popd;
        return 1;
    }
    reportline (2, "tarpkg:unpack: Successfully unpacked $pkgname");
    popd;

    return 0;
}

sub rpc_do {
    my ($rpc, $debugname, @args) = @_;

    my $ret = $rpc->send_request (@args);
    unless (ref $ret) {
        reportline (1, "$debugname: XML-RPC Error: $ret");
        die $ret;
    }
    if (is_fault $ret) {
        reportline (1, "$debugname: XML-RPC Error: " . $ret->string);
        die $ret->string;
    }
    reportline (4, "$debugname: XML-RPC Return value: ", $ret->value);
    return $ret->value;
}

sub pkg_get {
    my ($module, $data) = @_;

    my $nodeid = $args{tarpkg_get_nodeid};
    unless ($nodeid) {
        reportline (1, "tarpkg_get: No node ID specified (use --tarpkg_get_nodeid)");
        return 1;
    }

    my ($host, $port) = split ':', $nodeid;
    unless ($host and $port) {
        reportline (1, "tarpkg_get: Invalid node ID \"$nodeid\"");
        return 1;
    }

    my $rpc = RPC::XML::Client->new ("http://$host:$port/RPC2");
    my $httpport = eval { rpc_do ($rpc, "tarpkg:get", "fileserver_port"); };
    if ($@) { return 1; }

    reportline (3, "tarpkg:get: Using package http://$host:$httpport/built-packages/$module->{name}.tar.gz");

    mkdirs $data->{archivedir};
    pushd $data->{archivedir};

    # wget won't generally clobber, so remove beforehand
    unlink "$module->{name}.tar.gz" if -f "$module->{name}.tar.gz";

    # get the latest one by using the version-less filename
    if (run_cmd ("wget -q http://$host:$httpport/built-packages/$module->{name}.tar.gz")) {
        reportline (1, "tarpkg:get: Could not download package $module->{name}.tar.gz");
        popd;
        return 1;
    }
    popd;

    return 0;
}

1;
