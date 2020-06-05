package Ximian::BB::Lint;

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

use Ximian::BB::Conf qw/make_rev/;

my %tests;

my $print_all;
my $describe;
my $module;
my $group;
my $testname;

my %results = ('fail' => {'color' => '', 'letter' => 'F'},
	       'pass' => {'color' => '', 'letter' => 'P'},
	       'warn' => {'color' => '', 'letter' => 'W'});
my $normal = '';

# store several of the BB data structures
my $target;
my $distro_info;
my $packsys_info;
my $conf;
my $archivedir;
my $rev;
my $serial;
my $version;

my %depth_tests;
my @test_list;

my $tmpdir = $ENV{'TMPDIR'} || '/tmp';

if (-t STDOUT and exists $ENV{'COLORTERM'}
    or $ENV{'TERM'} eq 'xterm'
    or $ENV{'TERM'} eq 'rxvt'
    or $ENV{'TERM'} eq 'xterm-color') {
    $results{'pass'}->{color} = "\033[1;32m";
    $results{'fail'}->{color} = "\033[1;31m";
    $results{'warn'}->{color} = "\033[1;33m";
    $normal = "\033[0;39m";
}

sub test_register {
    my $opts = shift;
    my $handler = shift;

    if (exists $opts->{packsys}) {
	return if ($opts->{packsys} ne $distro_info->{packsys});
    }

    if (exists $opts->{target}) {
	return if ($target !~ /$opts->{target}/);
    }

    $opts->{type} = $opts->{type} || "fail";
    $opts->{handler} = $handler;
    $opts->{depth} = 0;
    $opts->{results} = [];

    $tests{$opts->{name}} = $opts;
}

sub test_log {
    my $test   = shift;
    my $result = shift;
    my $log    = shift;

    chomp $log if $log;

    return if $result eq 'pass' and not $print_all;
    my $logvars = $results{$result};

    my $str = "$logvars->{'color'}$logvars->{'letter'}$normal:";
    $str .= " $module: $test";

    if ($log) {
	my $tmp = $log;
	my @log_lines = split /\n/, $tmp;
	if (scalar (@log_lines) > 1) {
	    $tmp =~ s/^/L:   /mg;
	    $str .= "\nL:\n$tmp\nL:";
	} else {
	    $str .= " ($log)";
	}
    }

    print "$str\n";

    if ($describe
	and not $tests{$test}->{'described'}) {
	my $log = $tests{$test}->{'description'};
	$log =~ s/^/I:   /mg;
	$log = "I:\n$log\nI:";
	print "$log\n";
	$tests{$test}->{'described'} = 1;
    }
}

sub test_fail {
    my $test = shift;
    my $log  = shift;

    push @{$tests{$test}->{'results'}}, [$tests{$test}->{'type'}, $log];
    test_log($test, $tests{$test}->{'type'}, $log);
}

sub test_pass {
    my $test = shift;
    my $log  = shift;

    push @{$tests{$test}->{'results'}}, ['pass', $log];
    test_log($test, 'pass', $log);
}

sub test_results {
    my @tests = keys %tests;

    my $passed = 0;
    my $failed = 0;
    my $warned = 0;

    foreach my $test (@tests) {
	my @results = @{$tests{$test}->{results}};
	foreach my $result (@results) {
	    next if not @{$result}[0];
	    $passed++ if @{$result}[0] eq 'pass';
	    $failed++ if @{$result}[0] eq 'fail';
	    $warned++ if @{$result}[0] eq 'warn';
	}
    }

    return { 'pass' => $passed,
	     'fail' => $failed,
	     'warn' => $warned };
}

sub register_module_tests {
    my $name   = shift;
    my $module = \%{"${name}::"};

    if (exists $module->{get_tests}) {
	foreach my $test (@{&{$module->{get_tests}}()}) {
	    test_register ($test, \&{$module->{"do_$test->{name}"}});
	}
    }

    if (exists $module->{get_overrides}) {
	foreach my $test (@{&{$module->{get_overrides}}()}) {
	    if (exists $tests{$test->{name}}) {
		foreach (keys %$test) {
		    $tests{$test->{name}}->{$_} = $test->{$_};
		}
	    }
	}
    }
}

sub get_target {
    return $target;
}

sub get_distro_info {
    return $distro_info;
}

sub get_packsys_info {
    return $packsys_info;
}

sub get_conf {
    return $conf;
}

sub get_archivedir {
    return $archivedir;
}

sub test_init {
    $module  = shift;

    my $opts = shift;
    $target = $opts->{target};
    $distro_info = $opts->{distro_info};
    $packsys_info = $opts->{packsys_info};
    $conf = $opts->{conf};
    $archivedir = $opts->{archivedir};
    $print_all = $opts->{print_all};
    $describe = $opts->{describe};
    $group = $opts->{group};
    $testname = $opts->{testname};
    $rev = $opts->{rev};
    $serial = $opts->{serial};
    $version = $opts->{version};
}

sub get_package_files {
    my $conf = shift;
    my $package = shift;
    my $package_name;

    my ($os, $osvers, $arch) = split(/-/, $target);
    my $targetarch = $arch;
    my $packsys = $distro_info->{packsys};

    if ($packsys eq "rpm") {
	my $arch = $conf->{build}->{default}->{psdata}->{buildarch}->{cdata}
	    || $arch;

	$package_name = "#{name}-#{ver}-#{rev}.$arch.rpm";
    } elsif ($packsys eq "dpkg") {
	foreach my $packageconf (values %{$conf->{build}->{default}->{package}}) {
	    my $packagename = $packageconf->{name} || $conf->{name};

	    if ($packagename eq $package) {
		if (exists $packageconf->{psdata} and exists $packageconf->{psdata}->{architecture}) {
		    $arch = $packageconf->{psdata}->{architecture}->{cdata};
		    if ($arch eq "any") {
			$arch = $targetarch;
		    }
		}
		last;
	    }
	}
	$package_name = "#{name}_#{ver}-#{rev}_$arch.deb";
    } elsif ($packsys eq "sd") {
	$package_name = "sd_depot/$conf->{build}->{default}->{name}/$package";
    } else {
	print "packsys $packsys is not supported.";
	return 0;
    }

    $package_name =~ s/\#\{name\}/$package/;
    $package_name =~ s/\#\{ver\}/$version/;
    my $rev = &make_rev (conf => $conf, os_conf => $distro_info,
			 rev => $rev, serial => $serial);
    $package_name =~ s/\#\{rev\}/$rev/;

    $arch = $targetarch;
    return [$package_name];
}

sub get_source_files {
    my $conf = shift;
    my $package = shift;
    my @sources;

    my $rev = &make_rev (conf => $conf, os_conf => $distro_info,
			 rev => $rev, serial => $serial);
    my $packsys = $distro_info->{packsys};

    if ($packsys eq "rpm") {
	push @sources, "$package-$version-$rev.src.rpm";
    } elsif ($packsys eq "dpkg") {
	$package = $conf->{srcname} || $conf->{name};
	push @sources, "${package}_${version}-${rev}.dsc";
	push @sources, "${package}_${version}-${rev}.diff.gz";
	push @sources, "${package}_${version}.orig.tar.gz";
    } elsif ($packsys eq "sd") {
	push @sources, "sd_depot";
    } else {
	print "packsys $packsys is not supported.";
	return 0;
    }

    return \@sources;
}

sub get_package_names {
    my @packages;
    my @sources;

    my %packages = %{$conf->{build}->{default}->{package}};
    my $name;

    foreach my $package (keys %packages) {
	next if not %{$packages{$package}};

	if (exists $packages{$package}->{name}) {
	    $name = $packages{$package}->{name};
	} else {
	    $name = $conf->{name};
	}
	push @packages, @{get_package_files ($conf, $name)};
    }

    # get source files
    if (exists $packages{default}->{name}) {
	$name = $packages{default}->{name};
    } else {
	$name = $conf->{name};
    }
    push @sources, @{get_source_files ($conf, $name)};
    return [\@packages, \@sources];
}

sub get_rpm_files {
    my $file = shift;
    my @files;

    chomp (my @conffiles = `rpm -qplc $file 2>&1`);
    chomp (my @docfiles =  `rpm -qpld $file 2>&1`);

    open LIST, "rpm -qvpl $file 2>&1 |";
    while(<LIST>) {
	last if m/contains no files/;
	m/^(\S+)\s+(?:\d+)?\s+(\S+)\s+(\S+)\s+(\d+)\s+.*?\s+(\/.*?)(?:\s+->\s+(.*))?\s*$/;

	my ($perms, $owner, $group, $size, $filename) = ($1, $2, $3, $4, $5);

	my $file = {
		    'perms'    => $perms,
		    'owner'    => $owner,
		    'group'    => $group,
		    'size'     => $size,
		    'filename' => $filename
		    };

	$file->{conf} = 1 if grep {$_ eq $filename} @conffiles;
	$file->{doc} = 1  if grep {$_ eq $filename} @docfiles;
	$file->{dir} = 1  if $perms =~ /^d/;
	$file->{symlink} = $6 if $6;

	push @files, $file;
    }
    close LIST;
    return \@files;
}

sub get_deb_files {
    my $file = shift;
    my @files;

    chomp(my $oldcwd = `pwd`);

    my $tmpdir = "$tmpdir/BBLint.$$";
    mkdir $tmpdir, 0777; chdir $tmpdir;
    system ("ar x $file control.tar.gz");
    system ("tar xfz control.tar.gz");

    my @conffiles;
    opendir DIR, ".";
    while (my $file = readdir DIR) {
	next if $file =~ /^\.+$/;
	next if not $file =~ /conffiles$/;
	open FILE, $file;
	while (my $line = <FILE>) {
	    chomp $line;
	    push @conffiles, $line;
	}
	close FILE;
    }
    closedir DIR;

    chdir $oldcwd;
    system ("rm -rf $tmpdir");

    open LIST, "dpkg -c $file 2>&1 |";
    while(<LIST>) {
	m/^(\S+)\s+(\S+)\/(\S+)\s+(\d+)\s+.*?\s+\.(\/.*?)(?:\s+->\s+(.*))?\s*$/;
	my ($perms, $owner, $group, $size, $filename) = ($1, $2, $3, $4, $5);

	my $file = {
		    'perms'    => $perms,
		    'owner'    => $owner,
		    'group'    => $group,
		    'size'     => $size,
		    'filename' => $filename
		    };

	$file->{conf} = 1 if grep {$_ eq $filename} @conffiles;
	$file->{dir} = 1 if $perms =~ /^d/;
	$file->{symlink} = $6 if $6;
	push @files, $file;
    }
    close LIST;
    return \@files;
}

sub get_sd_files {
    # Sorry for this overloaded crap.  We should redesign this.
    my $depot = shift;
    $depot =~ /^(.*)\/([^\/]+)\/([^\/]+)$/;
    $depot = $1;
    my $product = $2;
    my $fileset = $3;
    my @files;

    my @raw_out = split (/\n\n  .*\nfile/,
			 `swlist -vl file -s $depot $product.$fileset 2>&1`);
    # weed out comments and filesets (which start with comments)
    @raw_out = grep {! /^#/} @raw_out;

    foreach my $file_record (@raw_out) {
        my @file_info = split (/\n/,  $file_record);

 	my %parsed_info;
 	grep {$parsed_info{$1} = $2 if (/^([^\s]+)\s+([^\s]*)$/)} @file_info;

 	$parsed_info{filename} = $parsed_info{path};
 	$parsed_info{dir} = 1 if $parsed_info{type} eq 'd';
 	$parsed_info{symlink} = $parsed_info{link_source}
 	  if ($parsed_info{type} eq 's');

 	push @files, \%parsed_info;
    }
    return \@files;
}

sub get_package_contents {
    my $file = shift;
    my @files;

    if ($distro_info->{packsys} eq "rpm") {
	push @files, @{get_rpm_files($file)};
    } elsif ($distro_info->{packsys} eq "dpkg") {
	push @files, @{get_deb_files($file)};
    } elsif ($distro_info->{packsys} eq "sd") {
	push @files, @{get_sd_files($file)};
    }
    return \@files;
}

# dependency resolution code from bb_build
sub resolve_dependencies {
    foreach my $test (keys %tests) {
        $test = $tests{$test};

        foreach my $depname (@{$test->{dependencies}}) {
            if (exists $tests{$depname}) {
                $test->{all_dependencies}->{$depname} = $tests{$depname};
                $tests{$depname}->{dependents}->{$test->{name}} = $test;
            } else {
                print STDERR "Could not find dependency '$depname' referenced by $test->{name}\n";
                exit (1);
            }
        }
    }
}

# Helper function for check_for_cycles.
sub cycle_check_for_test {
    my $initial_test = shift;
    my $test = shift;
    my $pass = shift;

    if (exists $test->{"cycle-check"}) {
        return $test->{depth};
    }

    if ($test->{"cycle-check-$pass"}) {
        print STDERR "Cycle found in the dependency graph.\n";
        print STDERR "The offending cycle: ";
        print_cycle ($test, $test);
        print STDERR "\n";
        exit (1);
    }
    $test->{"cycle-check-$pass"} = 1;

    foreach my $child (values %{$test->{all_dependencies}}) {
        $test->{depth} += cycle_check_for_test ($initial_test, $child, $pass);
        map
          {
              $test->{dense_dependencies}->{$_} = $tests{$_};
              $tests{$_}->{dense_dependents}->{$test->{name}} =
                $test;
          }
            keys %{$child->{dense_dependencies}};
        $child->{dense_dependents}->{$test->{name}} = $test;
        $test->{dense_dependencies}->{$child->{name}} = $child;
    }

    $test->{"cycle-check"} = 1;
    push @{$depth_tests{$test->{depth}}}, $test;
    return $test->{depth};
}

sub check_for_cycles {
    my $pass_num = 0;
    foreach my $test (values %tests) {
        cycle_check_for_test ($test, $test, $pass_num++);
    }
}

# Fill @test_list with a flattened version of the dependency graph.
sub flatten_graph {
    foreach (sort { $a <=> $b } keys %depth_tests) {
        push @test_list, @{$depth_tests{$_}};
    }
}

sub mark_all {
    my ($attribute, $value) = @_;

    foreach $test (@test_list) {
        $test->{$attribute} = $value;
    }
}

sub mark_dependencies {
    my ($node, $attribute, $value) = @_;

    foreach (keys %{$node->{dense_dependencies}}) {
        $child = $tests{$_};
        $child->{$attribute} = $value;
    }
}

sub mark_dependents {
    my ($node, $attribute, $value) = @_;

    foreach (keys %{$node->{dense_dependents}}) {
        $child = $tests{$_};
        $child->{$attribute} = $value;
    }
}

sub test_failed {
    my $test = shift;

    foreach my $result (@{$test->{results}}) {
	return 1 if (not $result->[0] eq 'pass');
    }
    return 0;
}

sub run_tests {
    resolve_dependencies;
    check_for_cycles;
    flatten_graph;

    if ($testname and $group) {
	foreach my $test (values %tests) {
	    if ($test->{name} eq $testname
		and grep {$_ eq $group} @{$test->{groups}}) {
		mark_dependencies ($test, 'run', 1);
		$test->{run} = 1;
	    }
	}
    } elsif ($testname) {
	foreach my $test (values %tests) {
	    if ($test->{name} eq $testname) {
		mark_dependencies ($test, 'run', 1);
		$test->{run} = 1;
	    }
	}
    } elsif ($group) {
	foreach my $test (values %tests) {
	    if (grep {$_ eq $group} @{$test->{groups}}) {
		mark_dependencies ($test, 'run', 1);
		$test->{run} = 1;
	    }
	}
    } else {
	mark_all ('run', 1);
    }

    foreach my $test (@test_list) {
	if ($test->{run}) {
	    &{$test->{handler}}($test->{name});

	    if (test_failed ($test)) {
		mark_dependents ($test, 'run', 0);
		mark_dependents ($test, 'failed_parent', "$test->{name}");
	    }
	} elsif ($test->{failed_parent}) {
	    test_fail ($test->{name}, "$test->{failed_parent} test failed");
	    mark_dependents ($test, 'failed_parent', "$test->{name}");
	}
    }
}

1;
