package Ximian::BB::XML::RPM;

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

use strict 'vars';
use Data::Dumper;

use File::Path;
use Ximian::Util ':all';

my $spec;
my $package;
my @lines;

my @toplevels = qw/description package prep build install clean post
    postun pre preun files changelog/;

sub parse_opt {
    if (m/^(.*?):\s+(.*)$/i) {
	$package->{"\L$1"} = $2;
	return 1;
    }
}

sub parse_dep {
    if (m/^(requires|provides|conflicts|obsoletes|prereqs|buildprereq|buildrequires|buildconflicts):\s+(.*)$/i) {
	my $type = "\L$1";
	my @deps = $2 =~ /(\S+\s+(?:[<=>]+)\s+[^\s,]+|[^\s,]+)[\s,]*/g;

	$package->{$type} = () if (not exists $package->{$type});
	push @{$package->{$type}}, @deps;
	return 1;
    }
}

sub section_ended {
    if ($lines[0] =~ /^%(\S+)/) {
	return grep {$_ eq $1} @toplevels;
    }
    return 0;
}

sub parse_section {
    if (m/^%(\S+)/) {
	return if not grep {$_ eq $1} @toplevels;
    } else {
	return;
    }

    my $section = "\L$1";

    # switch back to the default package once we hit %prep
    $package = $spec->{default} if $section eq 'prep';

    my $text;

    $text .= $1 if ($_ =~ /-p\s+(.*)$/);
    while (scalar @lines and not section_ended()) {
	$text .= shift @lines;
    }

    return 1 if not $text;
    $text =~ s/\s+$//m;
    $text =~ s/\#.*$//mg;
    $package->{$section} = $text if $section ne 'changelog';
    return 1;
}

sub change_package {
    m/^%(?:package|files).*\s+(\S+)$/;
    $spec->{$1} = {} if not exists $spec->{$1};
    $package = $spec->{$1};
}

sub build_xml {
    my $xml = {};

    $xml->{targetset} = {};

    my $ts = $xml->{targetset};

    $ts->{filter}->{i} = [ ".*" ];

    $ts->{rcsid}   = [ "\$" . "Id: \$" ];  # ugh, cvs wants to expand this
    $ts->{name}    = [ $spec->{default}->{name} ];
    $ts->{version} = [ $spec->{default}->{version} ];
    $ts->{rev}     = [ $spec->{default}->{release} ];
    $ts->{serial}  = [ 1 ];

    $ts->{psdata} = [];

    my $license = $spec->{default}->{copyright} || $spec->{default}->{license};
    push @{$ts->{psdata}}, {id => 'copyright', cdata => $license};
    push @{$ts->{psdata}}, {id => 'url', cdata => $spec->{default}->{url}};

    # write the sources and patches

    $ts->{build}->{id}      =   "default";
    $ts->{build}->{prepare} = [ "[[configure]]" ];
    $ts->{build}->{compile} = [ "\${MAKE}" ];
    $ts->{build}->{install} = [ "[[install]]" ];

    $ts->{build}->{package} = [];

    foreach my $name (keys %$spec) {
	my $specpack = $spec->{$name};
	my $package = {};

	$package->{id}     =   $name;
	$package->{name}   = [ $specpack->{name} ];
	$package->{psdata} = [];

	my $group = $specpack->{group} || $spec->{default}->{group};
	push @{$package->{psdata}}, {id => 'group', cdata => $group};

	$package->{description}->{h} = [ $specpack->{summary} ];
	$package->{description}->{p} = [];

	my @paragraphs = split /\n\n/, $specpack->{description};
	push @{$package->{description}->{p}}, @paragraphs;

	if (exists $specpack->{files}) {
	    my @files = split /\n/, $specpack->{files};

	    foreach my $file (@files) {
		$file =~ s,^\s+,,;
		next if $file =~ /^%defattr/;

		$file =~ s,\%(?:attr|lang|dir)(\(.*?\))?\s+,,;

		$file =~ s,^\%dir\s+,,g;

		$file =~ s,\%{_?_prefix},[[prefix]],g;
		$file =~ s,\%{__share},/share,g;
		$file =~ s,\%{_bindir},[[prefix]]/bin,g;
		$file =~ s,\%{_libdir},[[prefix]]/lib,g;
		$file =~ s,\%{_datadir},[[prefix]]/share,g;
		$file =~ s,\%{_includedir},[[prefix]]/include,g;
		$file =~ s,\%{_mandir},[[mandir]],g;

		next if $file =~ /^\s*$/;

		if ($file =~ /^%doc\s+(.*)$/) {
		    $package->{docs}->{i} = [] if not exists $package->{docs};
		    push @{$package->{docs}->{i}}, split /\s+/, $1;
		} elsif ($file =~ /^%config\S*\s+(.*)$/) {
		    $package->{conffiles}->{i} = [] if not exists $package->{conffiles};
		    push @{$package->{conffiles}->{i}}, $1;
		} else {
		    $package->{files}->{i} = [] if not exists $package->{files};
		    push @{$package->{files}->{i}}, $file;
		}
	    }
	}

	my %script_names = (post   => 'postinst',
			    pre    => 'preinst',
			    postun => 'postrm',
			    preun  => 'preuninst');

	foreach my $script (qw/post pre postun preun/) {
	    my $name = $script_names{$script};
	    next if not exists $specpack->{$script};

	    $package->{script} = [] if not exists $package->{script};

	    push @{$package->{script}}, { id=>$name,
					  i=>$specpack->{$script}};
	}

	foreach my $dep (qw/requires provides conflicts obsoletes prereqs/) {
	    next if (not exists $specpack->{$dep});

	    my $content = [];

	    foreach my $item (@{$specpack->{$dep}}) {
		next if $dep eq 'provides' and $item =~ /ximrev/;
		push @{$content}, $item;
	    }

	    next if not scalar @$content;

	    $package->{dep} = [ ] if not exists $package->{deps};
	    push @{$package->{dep}}, { id=>$dep, i=>$content };
	}

	push @{$ts->{build}->{package}}, $package;

	foreach my $dep (qw/buildprereq buildrequires buildconflicts/) {
	    next if (not exists $specpack->{$dep});

	    my $content = [];

	    foreach my $item (@{$specpack->{$dep}}) {
		push @{$content}, $item;
	    }

	    $ts->{build}->{builddeps} = [ ] if not exists $ts->{build}->{builddeps};
	    push @{$ts->{build}->{builddeps}}, { id=>$dep, i=>$content };
	}
    }

    return $xml;
}

sub read_srpm {
    my $file = shift;
    my $tmpdir = "/tmp/BB-RPM.$$";
    mkdir $tmpdir || die "can't create directory: $tmpdir";

    pushd $tmpdir;
    system ("rpm2cpio $file |cpio -i >/dev/null 2>&1");
    my @specs = glob("$tmpdir/*.spec");

    unless (scalar(@specs)) {
	popd;
	rmtree ($tmpdir);
	return undef;
    }

    my $xml = read_spec ("$specs[0]");
    popd;
    rmtree ($tmpdir);
    return $xml;
}

sub read_spec {
    my $file = shift;

    $spec = {};
    $package = $spec->{default} = {};

    open FILE, $file;
    @lines = <FILE>;
    close FILE;

    while($_ = shift @lines) {
	s/\#.*$//;  # remove comments
	if (m/^%package\s+.*\S+$/) {
	    change_package;
	    next;
	}
	change_package if m/^%files\s+\S+$/;

	parse_section ||
	    parse_dep ||
		parse_opt
	    }

    # apply some of RPM's behavior to the packages
    foreach (keys %{$spec}) {
	next if $_ eq 'default';
	my $package = $spec->{$_};
	$package->{name} = $_
	    if not exists $package->{name};
    }

    return build_xml;
}

1;
