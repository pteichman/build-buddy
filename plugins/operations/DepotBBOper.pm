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

#------------------------------------------------------------------------------
# Manage HP-UX Depots and their contents
#------------------------------------------------------------------------------

package DepotBBOper;

use Ximian::Run ':all';

sub get_operations {
    return [
	    { name => "depot:make-bundles",
	      description => "Make bundles from the hpux-bundles.conf.",
	      run => [ 'init_bundles', 'module_bundles' , 'finalize_bundles' ] },
	    { name => "depot:make-files",
	      description => "Make depots from the bundles psf file.",
	      run => [ 'init_bundles' , 0 , 'make_depots' ] },
	    { name => "depot:clean",
	      description => "Remove the HP/UX sd_depot.",
	      run => [ 'init_depot', 0 , 0 ] },
	    { name => "depot:rebuild",
	      description => "Re-make the HP/UX sd_depot from .depot files.",
	      run => [ 0 , 'module_depot', 0 ] },
	   ];
}

#------------------------------------------------------------------------------

use Ximian::Util ':all';

$bundle_conf = undef;

my %args;
parse_args
    (\%args,
     [
      {names => ["bundle_revision"], type => "=s", default => ""},
     ]);

sub read_config (%) {
    die "read_config: Options must be name => value pairs"
	if (@_ % 2);
    my $opts = { @_ };
    my $conf = undef;

    require Ximian::XML::Simple;
    $conf = eval { Ximian::XML::Simple::XMLin
	    ($opts->{config},
	     searchpath => [ qw(.) ],
	     keyattr => [ qw(id) ],
	     forcearray => [ qw( targetset bundle depot psdata i l p) ],
	     contentkey => 'cdata') };
    die "Error loading package config file: $@"	unless (defined $conf);
    return $conf;
}

sub init_bundles {
    my $data = shift;
    my $rawconf = read_config (config => "build/conf/hpux-bundles.conf");
    my $new_conf = {};
    require BB;
    BB::merge_filter_targetsets (conf => $new_conf,
				 targetsets => $rawconf->{targetset},
				 packsys => $data->{packsys},
				 os => $data->{os},
				 osvers => $data->{osvers},
				 arch => $data->{arch},
				 debug => 0);
    $bundle_conf = $new_conf;
}

sub module_bundles {
    my ($module, $conf, $data) = @_;
    my $ret = undef;

    print "Running make-bundles on: $module->{name}\n";

    my $name = $conf->{build}->{default}->{name} || $conf->{name};
    my $version = $conf->{version} . "." . $conf->{rev};
    my @filesets = @{BB::get_package_names ($conf)};
    my $fileset_prefix = $conf->{build}->{default}->{psdata}->{fileset_prefix}->{cdata};
    push @filesets, "$fileset_prefix-NOTES", "$fileset_prefix-SRC";

    foreach my $fileset (@filesets) {
	$fileset = "$name.$fileset";
	foreach my $bundle (values %{$bundle_conf->{bundle}}) {
	    push @{$bundle->{pkglist}}, [$fileset, $version]
		if (BB::filter_match (undef, $fileset, $bundle->{packages}));
	}
    }
    return 0;
}

sub data_helper {
    my ($bundle, $tag, $default) = @_;
    return $bundle->{psdata}->{$tag}?
	$bundle->{psdata}->{$tag}->{cdata} : $default;
}

sub finalize_bundles {
    my ($success, $data) = @_;

    open PSF, ">ximian-gnome-hpux.psf";
    print PSF <<EOF;
# PSF file for packaging Ximian GNOME into a series of bundles.
# Generated @{[scalar gmtime]} GMT by Ximian build system.
#
# bb_build rcsid: $data->{rcsid}

# To package:
#    Build packages with bb_do, which creates a working depot under $data->{archivedir}
#    swpackage -x compress_files=true -x compression_type=gzip -x compress_cmd=/usr/contrib/bin/gzip -x reinstall_files=true -s ximian-gnome-hpux.psf @ working-depot
#    swpackage -x media_type=tape -x reinstall_files=true -s working-depot @ depot-file.depot

vendor
	tag		Ximian
	title		Ximian, Inc.
	description	"Ximian, Inc. <www.ximian.com> provides free software
desktop services based on the GNOME <www.gnome.org> environment for 
Unix-like operating systems."
end

vendor
	tag		HP
	title		Hewlett-Packard Company
	description	"Hewlett-Packard Company"
end

EOF
    foreach my $bundle (values %{$bundle_conf->{bundle}}) {
	$revision	= ($args{bundle_revision} ||
			   data_helper ($bundle, 'revision', "0.0.no-revision"));
	$architecture	= data_helper ($bundle, 'architecture',
				       "HP-UX_B.11.00_32/64");
	$vendor_tag	= data_helper ($bundle, 'vendor_tag', "HP");
	$machine_type	= data_helper ($bundle, 'machine_type', "*");
	$os_name 	= data_helper ($bundle, 'os_name', "HP-UX");
	$os_release	= data_helper ($bundle, 'os_release', "?.11.*");
	$os_version	= data_helper ($bundle, 'os_version', "*");
	$category_tag	= data_helper ($bundle, 'category_tag', "HPUXAdditions");
	$category_title	= data_helper ($bundle, 'category_title',
				       "Additional HP-UX Functionality");
	$is_protected	= data_helper ($bundle, 'is_protected', "FALSE");
	$is_reference	= data_helper ($bundle, 'is_reference', "TRUE");
	$hp_ii_factory_integrate = data_helper ($bundle,
					       'hp_ii_factory_integrate',"TRUE");
	$hp_ii_title	= data_helper ($bundle, 'hp_ii_title', "XimianBundle");
	$hp_ii_desktop	= data_helper ($bundle, 'hp_ii_desktop', "FALSE");
	$hp_ii_load_with = data_helper ($bundle, 'hp_ii_load_with', "all");
	$hp_srdo	= data_helper ($bundle, 'hp_srdo',
				       "swtype=I;user=B;bundle_type=C");
	$description = "\"";
	$description .= $_ foreach (@{$bundle->{description}->{p}});
	$description .= "\"";

	print PSF <<EOF;
bundle
	tag		$bundle->{tag}     # HP-assigned, don't change!
	title		$bundle->{description}->{h}
	description	$description
	revision	$revision
	architecture	$architecture
	vendor_tag	$vendor_tag
	machine_type	$machine_type
        os_name         $os_name
        os_release      $os_release
        os_version      $os_version
        category_tag    $category_tag
        category_title  $category_title
        is_protected    $is_protected
        is_reference    $is_reference
        hp_ii           "factory_integrate=$hp_ii_factory_integrate;
                        title=$hp_ii_title;
                        desktop=$hp_ii_desktop;
                        load_with=$hp_ii_load_with"
        hp_srdo         $hp_srdo
EOF

	print PSF "\tcontents\t$_->[0],r=$_->[1],a=$architecture,v=HP\n"
	    foreach (@{$bundle->{pkglist}});
	print PSF "\n\n";
    }
    close PSF;
    print "Creating bundles in sd_depot...\n";
    run_cmd("swpackage",
            "-x", "reinstall_files=true",
            "-x", "compress_files=true",
            "-x", "compression_type=gzip",
            "-x", "compress_cmd=/usr/contrib/bin/gzip",
            "-s", "ximian-gnome-hpux.psf",
            "@", "$data->{archivedir}/sd_depot");
}

#------------------------------------------------------------------------------

sub make_depots {
    my ($success, $data) = @_;

    my @make_depot_base = ("swpackage",
			   "-x", "reinstall_files=true",
			   "-x", "media_type=tape",
			   "-x", "autoselect_dependencies=false",
			   "-s", "$data->{archivedir}/sd_depot");

    foreach my $depotid (keys %{$bundle_conf->{depot}}) {
	my @bundles = @{$bundle_conf->{depot}->{$depotid}->{bundles}->{i}};
	print "Making depot for $depotid depot (bundles @bundles)...\n";
	run_cmd(@make_depot_base,
                @bundles, "@", "$data->{archivedir}/$bundle_conf->{depot}->{$depotid}->{file}");
    }
}

#------------------------------------------------------------------------------

sub init_depot {
    my $data = shift;
    run_cmd ("rm -rf $data->{archivedir}/sd_depot") &&
	die "Could not remove $data->{archivedir}/sd_depot\n";
}

sub module_depot {
    my ($module, $conf, $data) = @_;
    my $ret = undef;
    my $revision = BB::make_rev (conf => $conf);
    my $filename = "$data->{archivedir}/" .
	"$conf->{name}-$conf->{version}.$revision.depot";

    if (-f $filename) {
	print "Copying $module->{name} to new depot.\n";
	$ret = run_cmd ("swcopy -s $filename \\* @ $data->{archivedir}/sd_depot");
    } else {
	return 0;
    }
    return $ret;
}

1;
