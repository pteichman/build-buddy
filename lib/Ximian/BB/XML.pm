package Ximian::BB::XML;

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
use Carp;

use Ximian::BB::XML::RPM;
use Ximian::BB::XML::Deb;
use Ximian::BB::XML::Tar;

require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [
	       'write',
	       'parse_version',
	      ]);

our @EXPORT_OK = ($EXPORT_TAGS{'all'});

my %dispatch = (
		"\.spec\$"       => \&Ximian::BB::XML::RPM::read_spec,
		"src\.rpm\$"     => \&Ximian::BB::XML::RPM::read_srpm,
		"control\$"      => \&Ximian::BB::XML::Deb::read_control,
		"\.t(ar\.)?gz\$" => \&Ximian::BB::XML::Tar::read_tar,
                "\.tar\.bz2\$"   => \&Ximian::BB::XML::Tar::read_tar,
	       );

sub new {
    my ($class, $file) = @_;
    my $self = {};

    while (my ($key, $value) = each %dispatch) {
	if ($file =~ /$key/) {
	    $self->{xml} = &$value($file);
	}
    }

    return bless $self, $class;
}

sub write_simple {
    my $tree = shift;
    require Ximian::XML::Simple;

    my $xmlout = Ximian::XML::Simple::XMLout($tree, rootname => 'module',
			xmldecl => "<?xml version=\"1.0\" ?>\n\n" .
			"<!DOCTYPE module SYSTEM \"helix-build.dtd\">\n");

    $xmlout =~ s/^(  *)</$1$1</mg;
    $xmlout .= "\n\n<!--\nLocal Variables:\nmode: xml\nEnd:\n-->\n";
    return $xmlout;
}

sub make_indent {
    my $level = shift;
    return "    " x $level;
}

my $tags =
    {
     'module'    => {'sort' => ['decl', 'packsys', 'targetset']},
     'list'      => {'sort' => ['l', 'i'],
		     'attr' => 'id'},
     'packsys'   => {'attr' => 'id',
		     'render' => \&render_with_newline},
     'os'        => {'attr' => 'id'},
     'osvers'    => {'attr' => 'id'},
     'arch'      => {'attr' => 'id',
		     'sort' => ['rcsid', 'name', 'version', 'epoch', 'rev',
			        'serial', 'srcname', 'tardir', 'tarname',
			        'psdata', 'source', 'patch', 'cvspatch',
			        'build']},
     'psdata'    => {'attr' => 'id',
		     'render' => \&render_with_newline},
     'build'     => {'attr' => 'id',
		     'sort' => ['name', 'prepare', 'compile',
			        'install', 'builddep', 'nofiles', 'package']},
     'package'   => {'attr' => 'id',
		     'sort' => ['name', 'psdata', 'dep', 'files', 'conffiles',
			        'docs', 'script', 'description']},
     'dep'       => {'attr' => 'id',
		     'render' => \&render_with_newline},
     'builddep'  => {'attr' => 'id'},
     'nofiles'  => {'render' => \&render_with_newline},
     'script'    => {'attr' => 'id'},
     'targetset' => {'sort' => ['rcsid', 'filter', 'name', 'version', 'epoch', 'rev',
			        'serial', 'srcname', 'tardir', 'tarname',
			        'psdata', 'source', 'patch', 'cvspatch',
			        'build']},
     'source'    => {'render' => \&render_with_newline},
     'Filter'    => {'render' => \&render_with_newline},
     'name'      => {'render' => \&render_with_newline},
     'serial'    => {'render' => \&render_with_newline},
     'files'     => {'render' => \&render_with_newline},
     'docs'      => {'render' => \&render_with_newline},
     'install'   => {'render' => \&render_with_newline},
     'conffiles' => {'render' => \&render_with_newline},
     'description' => {'render' => \&render_description},
    };

sub render_with_newline {
    return render(@_, 1) . "\n";
}

sub render_description {
    my $tree  = shift;
    my $tag   = shift;
    my $level = shift;

    my $indent = make_indent($level);

    my $str = "$indent<$tag>\n";
    $str .= "<h>$tree->{h}->[0]</h>\n" if exists $tree->{h};

    foreach my $p (@{$tree->{p}}) {
	$str .= "<p>$p</p>\n";
    }

    $str .= "$indent</$tag>\n";
    return $str;
}

sub order_tags {
    my $tree = shift;
    my $tag  = shift;

    my @elements = keys %$tree;
    my @sorted = ();

    if (exists $tags->{$tag}->{sort}) {
	@sorted = @{$tags->{$tag}->{sort}};
    }

    my @final;
    foreach my $elt (@sorted) {
	if (exists $tree->{$elt}) {
	    push @final, $elt;
	    @elements = grep {$_ ne $elt} @elements;
	}
    }

    @final = (@final, sort @elements);

    return \@final;
}

sub default_first {
    if (ref $a eq 'HASH' and ref $b eq 'HASH') {
	if (exists $a->{id} and exists $b->{id}) {
	    return -1 if $a->{id} eq 'default';
	    return  1 if $b->{id} eq 'default';
	    return $a->{id} cmp $b->{id};
	}
    }
    return $a cmp $b;
}

sub render {
    my ($tree, $tag, $level, $ignore_func) = @_;

    return &{$tags->{$tag}->{render}}($tree, $tag, $level)
	if exists $tags->{$tag}->{render} and not $ignore_func;

    my $indent = make_indent($level);

    my $str = "";

    if ((defined $tree) and (ref $tree eq 'HASH')) {
	my @elements = @{order_tags($tree, $tag)};

	if (exists $tags->{$tag}->{attr}) {
	    @elements = grep {$_ ne $tags->{$tag}->{attr}} @elements;

	    if (not scalar @elements) {
		$str .= "$indent<$tag $tags->{$tag}->{attr}=\"$tree->{$tags->{$tag}->{attr}}\"/>\n";
	    } elsif (exists $tree->{cdata}) {
		$str .= "$indent<$tag $tags->{$tag}->{attr}=\"$tree->{$tags->{$tag}->{attr}}\">$tree->{cdata}</$tag>\n";
	    } else {
		$str .= "$indent<$tag $tags->{$tag}->{attr}=\"$tree->{$tags->{$tag}->{attr}}\">\n";
		foreach my $elt (@elements) {
		    $str .= render($tree->{$elt}, $elt, $level+1);
		}
		$str .= "$indent</$tag>\n";
	    }
	} else {
	    $str .= "$indent<$tag>\n";
	    foreach my $elt (@elements) {
		$str .= render($tree->{$elt}, $elt, $level+1);
	    }
	    $str .= "$indent</$tag>\n";
	}
    } elsif (ref $tree eq 'ARRAY') {
	my @sorted = sort default_first @$tree;
	foreach my $elt (@sorted) {
	    $str .= render($elt, $tag, $level, 1);
	}
    } elsif (not ref $tree) {
	$str .= "$indent<$tag>$tree</$tag>\n";
    }

    return $str;
}

sub write {
    my $self = shift;
    my $tree = $self->{xml};

    my $xmlout = "<?xml version=\"1.0\" ?>\n\n" .
	"<!DOCTYPE module SYSTEM \"helix-build.dtd\">\n\n";

    $xmlout .= render($tree, 'module', 0);
    $xmlout .= "\n\n<!--\nLocal Variables:\nmode: xml\nEnd:\n-->\n";
    return $xmlout;
}

sub get_report (%);

# =========================================================
# Reporting functions
# =========================================================

# Return a text summary of a module's XML file.
#   Egg::get_report(opt => val, ...)
#   opts are:  debug (boolean)
#              conf (hashref)

sub get_report (%) {
    croak "Egg::get_report: Options must be name => value pairs"
	if (@_ % 2);
    my $opts = { @_ };
    my $conf = $opts->{conf};
    my $defaults;
    my @report;

    $defaults = $conf->{packsys}->{default}->{os}->{default}->{osvers}->{default}->{arch}->{default};
    # destructive check, but who cares
    if (!$defaults) {
	foreach my $tgset (@{$conf->{targetset}}) {
	    $defaults = $tgset if (1 == $#{$tgset->{filter}->{i}}
				   && ".*" == $tgset->{filter}->{i}->[0]);
	}
    }
    die "Could not find defaults section in XML\n" if (!$defaults);

    if ($opts->{debug}) {
	print "Conf defaults XML tree:\n", Data::Dumper::Dumper($defaults);
    }

    $report[0] = <<EOF;
Name: $defaults->{name};
Version: $defaults->{version};
EOF

    $report[$#report + 1] = <<EOF;
Prepare: $defaults->{build}->{default}->{prepare};
Compile: $defaults->{build}->{default}->{compile};
Install: $defaults->{build}->{default}->{install};
EOF

    my $pkginfo = "";
    foreach my $pkgid (keys %{$defaults->{build}->{default}->{package}}) {
	my $pkgref = $defaults->{build}->{default}->{package}->{$pkgid};

	$pkginfo .= "id \"$pkgid\" ($pkgref->{name}):\n";
	$pkginfo .= "    Description: \"$pkgref->{description}->{h}\"\n";

	if ($pkgref->{dep}) {
	    $pkginfo .= "    Dependencies:\n";
	    foreach my $depid (keys %{$pkgref->{dep}}) {
		$pkginfo .= "        $_ ($depid)\n"
		    foreach (@{$pkgref->{dep}->{$depid}->{i}});
	    }
	}
    }
    $report[$#report + 1] = $pkginfo;

    if ($opts->{debug}) {
	print "Overrides XML tree:\n", Data::Dumper::Dumper($conf->{targetset});
    }

    my $overrides = "";
    if ($conf->{targetset}) {
	foreach my $tgset (@{$conf->{targetset}}) {
	    $overrides .= "$_, " foreach (@{$tgset->{filter}->[0]->{i}});
	    $overrides =~ s/, $/:\n/;
	    $overrides .= "    stuff\n";
	}
    }
    $report[$#report + 1] = $overrides;

    return \@report;
}

sub parse_version {
    my $str = shift;

    my $package = "none";
    my $version = "none";

    # drop the extension from the filename
    $str =~ s/(\.orig)?(\.tar\.gz|\.tgz|\.tar\.bz2)(-[0-9]+)?$//;

    # if there's no dash or underscore, use the first transition
    # between alpha and numeric as the version separator
    if ($str !~ /[-_]/) {
        if ($str =~ /^(\D+)(\d.*)$/) {
            $package = $1;
            $version = $2;
        } else {
            $package = $str;
        }
    } elsif ($str =~ /^(.*?)(?:[-_.])(v?[0-9.].*)$/) {
        $package = $1;
        $version = $2;
    } else {
        $package = $str;
    }
    return [$package, $version];
}

1;

