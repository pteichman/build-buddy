package Ximian::BB::XML::Deb;

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

use strict;
use Ximian::Util ':all';

my $packages = {};
my $default;

sub build_xml {
    my $xml = {};

    $xml->{targetset} = {};

    my $ts = $xml->{targetset};

    $ts->{filter}->{i} = [ ".*" ];

    $ts->{rcsid}   = [ "\$" . "Id: \$" ];  # ugh, cvs wants to expand this
    $ts->{name}    = [ $packages->{toplevel}->{source} ];
    $ts->{version} = [ $packages->{toplevel}->{version} ];
    $ts->{rev}     = [ $packages->{toplevel}->{rev} ];
    $ts->{serial}  = [ $packages->{toplevel}->{serial} ];

    if (exists $packages->{toplevel}->{epoch}) {
	$ts->{epoch} = [ $packages->{toplevel}->{epoch} ];
    }

    $ts->{psdata} = [];
    push @{$ts->{psdata}}, {id => 'section', cdata => $packages->{toplevel}->{section}};
    push @{$ts->{psdata}}, {id => 'priority', cdata => $packages->{toplevel}->{priority}};

    $ts->{build}->{id}      =   "default";
    $ts->{build}->{prepare} = [ "[[configure]]" ];
    $ts->{build}->{compile} = [ "\${MAKE}" ];
    $ts->{build}->{install} = [ "[[install]]" ];

    $ts->{build}->{package} = [];

    foreach my $name (grep {$_ ne 'toplevel'} keys %$packages) {
	my $debpack = $packages->{$name};
	my $package = {};

	$package->{id} = $name;
	$package->{name} = $name;

	$package->{psdata} = [];
	push @{$package->{psdata}}, {id => 'section', cdata => $debpack->{section}};
	push @{$package->{psdata}}, {id => 'architecture', cdata => $debpack->{architecture}};

	if (exists $debpack->{files}) {
	    $package->{files}->{i} = [];
	    foreach my $file (@{$debpack->{files}}) {
		push @{$package->{files}->{i}}, "/$file";
	    }
	}

	if (exists $debpack->{conffiles}) {
	    $package->{conffiles}->{i} = [];
	    foreach my $file (@{$debpack->{conffiles}}) {
		push @{$package->{conffiles}->{i}}, "/$file";
	    }
	}

	if (exists $debpack->{docs}) {
	    $package->{docs}->{i} = [];
	    foreach my $file (@{$debpack->{docs}}) {
		push @{$package->{docs}->{i}}, $file;
	    }
	}

	foreach my $type (qw/depends pre-depends suggests recommends conflicts provides replaces/) {
	    next if (not exists $debpack->{$type});

	    $package->{dep} = [] if not exists $package->{dep};
	    push @{$package->{dep}}, { id=>$type, i=>$debpack->{$type}};
	}

	$package->{description}->{h} = [ $debpack->{summary} ];
	$package->{description}->{p} = $debpack->{description};

	push @{$ts->{build}->{package}}, $package;
    }

    return $xml;
}

sub read_file {
    my $package = shift;
    my $dir     = shift;
    my $file    = shift;

    # read the package's docs list
    my $filename;
    if ($package eq $default) {
	$filename = $file;
    } else {
	$filename = "$package.$file";
    }

    if (-e "$dir/$filename") {
	open FILES, "$dir/$filename";
	$packages->{$package}->{$file} = [];

	while (<FILES>) {
	    chomp;
	    push @{$packages->{$package}->{$file}}, split (/\s+/, $_);
	}
	close FILES;
    }
}

sub read_control {
    my $file = shift;
    my $dir  = get_dirname($file);

    open CONTROL, $file;

    while (<CONTROL>) {
	chomp;
	last if m/^$/;

	if (m/Source:\s+(\S+)\s*$/) {
	    $packages->{'toplevel'}->{'source'} = $1;
	} elsif (m/Section:\s+(\S+)\s*$/) {
	    $packages->{'toplevel'}->{'section'} = $1;
	} elsif (m/Priority:\s+(\S+)\s*$/) {
	    $packages->{'toplevel'}->{'priority'} = $1;
	}
    }

    my $package;
    while (<CONTROL>) {
	chomp;

	my $tmp;

	if (m/Package:\s+(\S+)\s*$/) {
	    $package = $1;
	    if (not $default) {
		$default = $package;
	    }
	} elsif (m/Section:\s+(\S+)\s*$/) {
	    $packages->{$package}->{'section'} = $1;
	} elsif (m/Architecture:\s+(\S+)\s*$/) {
	    $packages->{$package}->{'architecture'} = $1;
	} elsif (m/Replaces:\s+(.*)\s*$/) {
	    $tmp = $1;
	    $tmp =~ s/>/&gt;/g;
	    $tmp =~ s/</&lt;/g;
	    $packages->{$package}->{'replaces'} = [] if not exists $packages->{$package}->{'replaces'};
	    @{$packages->{$package}->{'replaces'}} = split(',\s+', $tmp);
	} elsif (m/Depends:\s+(.*)\s*$/) {
	    $tmp = $1;
	    $tmp =~ s/>/&gt;/g;
	    $tmp =~ s/</&lt;/g;
	    $packages->{$package}->{'depends'} = [] if not exists $packages->{$package}->{'depends'};
	    @{$packages->{$package}->{'depends'}} = split(',\s+', $tmp);
	} elsif (m/Conflicts:\s+(.*)\s*$/) {
	    $tmp = $1;
	    $tmp =~ s/>/&gt;/g;
	    $tmp =~ s/</&lt;/g;
	    $packages->{$package}->{'conflicts'} = [] if not exists $packages->{$package}->{'conflicts'};
	    @{$packages->{$package}->{'conflicts'}} = split(',\s+', $tmp);
	} elsif (m/Suggests:\s+(.*)\s*$/) {
	    $tmp = $1;
	    $tmp =~ s/>/&gt;/g;
	    $tmp =~ s/</&lt;/g;
	    $packages->{$package}->{'suggests'} = [] if not exists $packages->{$package}->{'suggests'};
	    @{$packages->{$package}->{'suggests'}} = split(',\s+', $tmp);
	} elsif (m/Provides:\s+(.*)\s*$/) {
	    $tmp = $1;
	    $tmp =~ s/>/&gt;/g;
	    $tmp =~ s/</&lt;/g;
	    $packages->{$package}->{'provides'} = [] if not exists $packages->{$package}->{'provides'};
	    @{$packages->{$package}->{'provides'}} = split(',\s+', $tmp);
	} elsif (m/Description:\s+(.*)\s*$/) {
	    $packages->{$package}->{'summary'} = $1;
	    while (<CONTROL>) {
		chomp;
		last if m/^$/;
		s/^\s+(.*\S+)$/$1/;
		next if m/^\.$/;
		$packages->{$package}->{'description'} = [] if not exists $packages->{$package}->{'description'};
		push @{$packages->{$package}->{'description'}}, $_;
	    }
	}
    }
    close CONTROL;

    open LOG, "$dir/changelog";
    $_ = <LOG>;
    $_ =~ /^\S+\s+\((\S+?)-(.*)\)/;

    my $epoch;
    my $version  = $1;
    my $revision = $2;
    my $serial   = 1;

    if ($version =~ /^(\d+):(.*)$/) {
	$packages->{'toplevel'}->{'epoch'} = $1;
	$version = $2;
    }

    if ($revision =~ /^(\d+).(?:helix|ximian).(\d+)$/) {
	$revision = $1;
	$serial = $2;
    } elsif ($revision =~ /^(?:helix|ximian).(\d+)$/) {
	$revision = undef;
	$serial = $1;
    }

    $packages->{'toplevel'}->{'version'} = $version;
    $packages->{'toplevel'}->{'rev'} = $revision;
    $packages->{'toplevel'}->{'serial'} = $serial;
    close LOG;

    foreach my $package (keys %$packages) {
	read_file($package, $dir, "files");
	read_file($package, $dir, "conffiles");
	read_file($package, $dir, "docs");
    }

    return build_xml();
}

1;
