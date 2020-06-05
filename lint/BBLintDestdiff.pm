package BBLintDestdiff;

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

sub get_tests {
    return [
	    { 'name' => 'destdiff',
	      'description' => "You have installed files that are not included in a package.",
	      'type' => 'warn',
	      'dependencies' => [
				 'built_check',
				],
	    },
           ];
}

sub get_dest_files {
    my @files;
    open INFO, "find dest |";
    while(<INFO>) {
        chomp;
        s/^dest//;
        next if ($_ eq "");

	my $file = { 'filename' => $_ };

	$file->{dir} = 1 if (-d "dest$_");
	push @files, $file;
    }
    close INFO;
    return \@files;
}

sub num_files_in_dir {
    my $dir = shift;
    my $count;
    opendir DIR, $dir || return 0;
    while($_ = readdir DIR) {
	next if m/^\.+$/;
	$count++;
    }
    closedir DIR;
    return $count;
}

sub do_destdiff {
    my $name = shift;

    my ($packages, $sources) = @{Ximian::BB::Lint::get_package_names()};
    my $archivedir = Ximian::BB::Lint::get_archivedir();

    if (not -d 'dest') {
	Ximian::BB::Lint::test_fail($name, "dest directory does not exist");
	return;
    }

    # build the list of files in dest
    my @destfiles = @{get_dest_files()};

    # build the list of files in the packages
    my @packfiles;
    foreach my $package (@$packages) {
	push @packfiles,
	    @{Ximian::BB::Lint::get_package_contents("$archivedir/$package")};
    }

    my @missing;
    foreach my $file (@destfiles) {
	if (not grep {$_->{filename} eq $file->{filename}} @packfiles) {
	    if ($file->{dir}) {
		next if (num_files_in_dir("dest$file->{filename}"));
	    }
	    next if Ximian::BB::Lint::get_distro_info->{packsys} eq 'sd'
		&& $file->{filename} =~ /^\/opt\/gnome\/src/;
	    push @missing, $file;
	}
    }

    if (@missing) {
	my $log = "files missing from the packages:\n";
	foreach (@missing) {
	    $log .= "\t$_->{filename}\n";
	}
	Ximian::BB::Lint::test_fail($name, $log);
    } else {
	Ximian::BB::Lint::test_pass($name);
    }
}

1;

