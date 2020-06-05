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
# Populate operation
#
# This operation tries the best it can to install packages from a given 
# directory.  It will install packages with different versions and revisions.
#
# This is kind of dumb, but it gets around the fact that what is in the build
# system xml isn't necessarily what is being shipped, ie it isn't necessarily
# 
#------------------------------------------------------------------------------

package PopulateBBOper;

use Ximian::Run ':all';
#use Ximian::Packsys ':all';

sub get_operations {
    return [
	    { name => "populate",
	      description => "Installs packages from a given directory.",
	      run => [ 0 , 'operation_populate', 0 ] },
	   ];
}

#------------------------------------------------------------------------------

sub path_glob {
    my ($fileglob, $path) = @_;

    my @path_components = split /:/, $path;
    my @ret;

    foreach $dir (@path_components) {
	push @ret, glob "$dir/$fileglob";
    }

    return \@ret;
}

# Right now finds the first match, but could be made to find things closest in
# version/rev
sub find_best_match  {
    my ($package_name, $files, $data) = @_;

    use File::Basename;

    my $suffix = "";
    my $revsep = "-";
    if ($data->{packsys} eq "dpkg") {
	$suffix = ".deb";
    } elsif ($data->{packsys} eq "rpm") {
	$suffix = ".rpm";
    }

    foreach my $path (@{$files}) {
	$_ = basename ($path);
	print "basename: $_\n";
	my $re = quotemeta ($package_name) . "-(.*)$revsep(.*)$suffix";
	if (/^$re/) {
	    print "$1, $2\n";
	    # Now we check if $1 and $2 look like valid version and rev strings
	    # FIXME: Do we have a good regexp for this?
	    if ($1 =~ /$revsep/) {
		next;
	    }
	    if ($2 =~ /$revsep/) {
		next;
	    }
	    # We found one that works
	    return $path;
	}
    }
    return "";
}

sub find_file_on_path {
    my ($file, $path) = @_;

    @path_components = split /:/, $path;

    foreach $dir (@path_components) {
	if (-e "$dir/$file") {
	    return "$dir/$file";
	}
    }
    return "";
}

sub fuzzy_find_package {
    my ($package, $conf, $data) = @_;
    my $package_path = ($ENV{PACKAGEPATH} || $data->{archivedir} || "");
    my $package_name = $package->{name} || $conf->{name};

    # First try to see if the requested file exists
    my $expected_filename = get_package_filename ($package_name,
						  $conf, $data->{target});
    $filename = find_file_on_path ($expected_filename, $package_path);
    if (-e $filename) {
	print "found $filename\n";
	return [$filename, 1];
    }

    # Now glob for files
    my $package_glob = "";
    if ($data->{packsys} eq "dpkg") {
	$package_glob = "$package_name.deb";
    } elsif ($data->{packsys} eq "rpm") {
	$package_glob = "$package_name-*.rpm"
    } else {
	print STDERR "$packsys is not supported by the populate operation.\n";
    }
    
    print "glob: $package_glob\n";
    my $files = path_glob ($package_glob, $package_path);
    foreach (@{$files}) {
	print "file: $_\n";
    }
    my $filename = find_best_match ($package_name, $files, $data);
    return [$filename, 0];
}

sub check_file_installed {
    my ($package_name, $file) = @_;
    my @package = get_package_version ($file);
    my @installed = get_installed_version ($package_name);
    return ($package[0] eq $installed[0] && $package[1] eq $installed[1] && $package[2] eq $installed[2]);
}

sub operation_populate {
    my ($module, $conf, $data) = @_;

    my $package_list = "";

    if (!($data->{packsys} eq "sd")) {
	foreach my $package (values %{$conf->{build}->{default}->{package}}) {
	    if (!exists ($package->{name})) {
		$package->{name} = $conf->{name};
	    }
	    ($filename, $exact) = @{fuzzy_find_package ($package, $conf, $data)};
	    if ($filename eq "") {
		print STDERR "Could not find suitable package for $package->{name}.\n";
		return 1;
	    } elsif ($exact == 0) {
		print "Using $filename for $package->{name}\n";
	    }
	    if (!check_file_installed ($package->{name}, $filename)) {
		if (exists $module->{deferrals}->{$package->{name}}) {
		    $deferred = $modules{$module->{deferrals}->{$package->{name}}};
		    push @{$deferred->{deferred}}, $filename;
		} else {
		    $package_list .= " $filename";
		}
	    }
	}
	
    } else {
	# FIXME: Do HP
 	print STDERR ("Populate doesn't work on hp-ux yet.\n");
	exit (1);
    }
	
    foreach (@{$module->{deferred}}) {
	$package_list .= " $_";
	print "Installing deferred package $_\n";
    }

    if ($package_list ne "") {
	# FIXME: This is duplicated from InstallBBOper.pm
	if ($data->{packsys} eq "dpkg") {
	    $package_add = "sudo dpkg --install [[path]]";
	} elsif ($data->{packsys} eq "rpm") {
	    $package_add = "sudo rpm -Uhv --oldpackage [[path]]";
	} elsif ($data->{packsys} eq "sd") {
	    $package_add = "swinstall -x reinstall=true -s [[path]] [[depot]]";
	}
	print "installing $package_list\n";
	my $cmd = "$package_add $data->{redirect}";
	$cmd =~ s/\[\[path\]\]/$package_list/;
	$cmd =~ s/\[\[depot\]\]/$conf->{build}->{default}->{name}/;
	
	my $ret = run_cmd ("$cmd");
	if ($ret != 0) {
	    print STDERR "Could not install packages for $module->{name}\n";
	    return $ret;
	} else {
	    print "Installation sucessful\n";
	}
    }
    return 0;
}

1;
