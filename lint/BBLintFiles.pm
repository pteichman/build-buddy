package BBLintFiles;

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
	    { 'name' => 'built_check',
	      'description' => "You should build this module.",
	    },
	    { 'name' => 'check_owners',
	      'description' => "You have files with invalid owners",
	      'dependencies' => [ 'built_check' ]
            },
	    { 'name' => 'check_groups',
	      'description' => "You have files with invalid groups",
	      'dependencies' => [ 'built_check' ]
	    },
	    { 'name' => 'check_paths',
	      'description' => "You have files in invalid places",
	      'dependencies' => [ 'built_check' ]
	    },
           ];
}

sub do_check_owners {
    my $name = shift;
    my $archivedir = Ximian::BB::Lint::get_archivedir();
    my @failed;
    my @valid_owners = qw/root bin games game/;

    my ($packages, $sources) = @{Ximian::BB::Lint::get_package_names()};

    foreach my $package (@$packages) {
	my $files = Ximian::BB::Lint::get_package_contents("$archivedir/$package");
	foreach my $file (@{$files}) {
	    if (not grep {$file->{owner} eq $_} @valid_owners) {
		push @failed, $file;
	    }
	}
    }

    if (scalar @failed) {
	my $log = "failed files:\n";
	foreach (@failed) {
	    $log .= "   $_->{'owner'} $_->{'filename'}\n";
	}
	chomp $log;
	Ximian::BB::Lint::test_fail ($name, $log);
    } else {
	Ximian::BB::Lint::test_pass ($name);
    }
}

sub do_check_groups {
    my $name = shift;
    my $archivedir = Ximian::BB::Lint::get_archivedir();
    my @failed;
    my @valid_owners = qw/root bin games game mail utmp/;

    my ($packages, $sources) = @{Ximian::BB::Lint::get_package_names()};

    foreach my $package (@$packages) {
	my $files = Ximian::BB::Lint::get_package_contents("$archivedir/$package");
	foreach my $file (@{$files}) {
	    if (not grep {$file->{owner} eq $_} @valid_owners) {
		push @failed, $file;
	    }
	}
    }

    if (scalar @failed) {
	my $log = "failed files:\n";
	foreach (@failed) {
	    $log .= "   $_->{'owner'} $_->{'filename'}\n";
	}
	chomp $log;
	Ximian::BB::Lint::test_fail ($name, $log);
    } else {
	Ximian::BB::Lint::test_pass ($name);
    }
}

sub do_built_check {
    my $name = shift;
    my $archivedir = Ximian::BB::Lint::get_archivedir();
    my @failed;

    my ($packages, $sources) = @{Ximian::BB::Lint::get_package_names()};

    foreach my $package (@$packages, @$sources) {
	push @failed, $package if not -e "$archivedir/$package";
    }

    if (scalar @failed) {
	my $log = "failed files:\n";
	foreach (@failed) {
	    $log .= "   $_\n";
	}
	chomp $log;
	Ximian::BB::Lint::test_fail ($name, $log);
    } else {
	Ximian::BB::Lint::test_pass ($name);
    }
}

sub do_check_paths {
    my $name = shift;
    my $archivedir = Ximian::BB::Lint::get_archivedir();
    my @failed;

    my ($packages, $sources) = @{Ximian::BB::Lint::get_package_names()};

    foreach my $package (@$packages) {
	my $files = Ximian::BB::Lint::get_package_contents("$archivedir/$package");
	foreach my $file (@{$files}) {
	    if ($file->{filename} =~ /^\/+home/) {
		push @failed, $file;
		next;
	    }

	    if (exists $file->{symlink}) {
		push @failed, $file if $file->{symlink} =~ /^\/+home/;
	    }
	}
    }

    if (scalar @failed) {
	my $log = "failed files:\n";
	foreach (@failed) {
	    if (exists $_->{symlink}) {
		$log .= "   $_->{filename} -> $_->{symlink}\n";
	    } else {
		$log .= "   $_->{filename}\n";
	    }
	}
	chomp $log;
	Ximian::BB::Lint::test_fail ($name, $log);
    } else {
	Ximian::BB::Lint::test_pass ($name);
    }
}

1;

