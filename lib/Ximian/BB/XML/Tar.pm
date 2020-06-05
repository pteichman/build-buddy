package Ximian::BB::XML::Tar;

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
use Ximian::BB::XML;
use Ximian::Util ':all';

sub read_tar {
    my $file = shift;
    my $xml  = {};

    my $info = inspect_tarball ($file);

    my $filename = get_basename($file);

    $xml->{targetset} = {};

    my $ts = $xml->{targetset};

    $ts->{filter}->{i} = [ ".*" ];

    $ts->{rcsid}   = [ "\$" . "Id: \$" ];  # ugh, cvs wants to expand this
    $ts->{name}    = [ $info->{module} ];
    $ts->{version} = [ $info->{version} ];
    $ts->{rev}     = [ 1 ];
    $ts->{serial}  = [ 1 ];

    $ts->{source}->{i} = "$filename-1";

    if (exists $info->{tarname}) {
	$ts->{tarname} = $info->{tarname};
    }

    if (exists $info->{tardir}) {
	$ts->{tardir} = $info->{tardir};
    }

    $ts->{build}->{id} = "default";

    if ($info->{module_build}) {
	$ts->{build}->{prepare} = [ '[[perl_mb_prepare]]' ];
	$ts->{build}->{compile} = [ './Build' ];
	$ts->{build}->{install} = [ './Build install' ];

	$ts->{build}->{nofiles}->{i} = [ '[[perlmoddir]]/perllocal.pod',
					 '[[perlmoddir]]/*/perllocal.pod'];

	$ts->{build}->{package} = [];

	$ts->{psdata} = [];
	push @{$ts->{psdata}}, {id=> 'url', cdata => "http://www.cpan.org/"};
	push @{$ts->{psdata}}, {id=> 'copyright', cdata => "Artistic"};

	my $package = {};
	$package->{id} = "default";
	$package->{name} = "perl-$info->{module}";

	$package->{files}->{i} = [ '[[perlmoddir]]',
				   '[[usrmandir]]/man*/*' ];

	$package->{docs}->{i} = [ 'README' ];

	$package->{description} =
	    { h => [ "$info->{module} extension for Perl5" ],
	      p => [ "This package provides a perl module." ] };

	$package->{psdata} = [ { id => 'group',
				 cdata => "Development/Perl" } ];

	push @{$ts->{build}->{package}}, $package;
    } elsif ($info->{makemaker}) {
	$ts->{build}->{prepare} = [ '[[perlprepare]]' ];
	$ts->{build}->{compile} = [ '[[perlmake]]' ];
	$ts->{build}->{install} = [ '[[perlinstall]]' ];

	$ts->{build}->{nofiles}->{i} = [ '[[perlmoddir]]/perllocal.pod',
					 '[[perlmoddir]]/*/perllocal.pod'];

	$ts->{build}->{package} = [];

	$ts->{psdata} = [];
	push @{$ts->{psdata}}, {id=> 'url', cdata => "http://www.cpan.org/"};
	push @{$ts->{psdata}}, {id=> 'copyright', cdata => "Artistic"};

	my $package = {};
	$package->{id} = "default";
	$package->{name} = "perl-$info->{module}";

	$package->{files}->{i} = [ '[[perlmoddir]]',
				   '[[usrmandir]]/man*/*' ];

	$package->{docs}->{i} = [ 'README' ];

	$package->{description} =
	    { h => [ "$info->{module} extension for Perl5" ],
	      p => [ "This package provides a perl module." ] };

	$package->{psdata} = [ { id => 'group',
				 cdata => "Development/Perl" } ];

	push @{$ts->{build}->{package}}, $package;
    } elsif ($info->{php}) {
	$ts->{build}->{prepare} = [ 'cp ../package.xml .' ];
	$ts->{build}->{compile} = [ 'mkdir -p $DESTDIR/usr/share/pear/--FIXME--; pear -d bin_dir=$DESTDIR/usr/bin -d doc_dir=$DESTDIR/usr/share/pear/docs -d ext_dir=$DESTDIR/usr/lib/php4 -d php_dir=$DESTDIR/usr/share/pear -d cache_dir=$DESTDIR/tmp/pear/cache -d data_dir=$DESTDIR/usr/share/pear/data -d test_dir=$DESTDIR/usr/share/pear/tests  install --force --nodeps package.xml' ];
	$ts->{build}->{install} = [ 'true' ];


	$ts->{psdata} = [];
	push @{$ts->{psdata}}, {id=> 'url', cdata => "http://www.php.org/"};
	push @{$ts->{psdata}}, {id=> 'copyright', cdata => "--FIXME--"};

	my $package =
	    {id => "default",
	     name => "php-$info->{module}",
	     files => {i => ['[[prefix]]/usr/share/pear/[A-Z]*',
			     '[[prefix]]/share/pear/docs/*']},
	     description => {h => ["$info->{module} extension for PHP"],
			     p => ["This package provides a PHP module."]},
	     psdata => [{id=> 'group', cdata => "Development/PHP"}]};
	$ts->{build}->{package} = [$package];
    } else {
	$ts->{build}->{prepare} = [ "[[configure]]" ];
	$ts->{build}->{compile} = [ "\${MAKE}" ];
	$ts->{build}->{install} = [ "[[install]]" ];

	$ts->{build}->{package} = [];

	$ts->{psdata} = [];
	push @{$ts->{psdata}}, {id=> 'url', cdata => "--FIXME--"};
	push @{$ts->{psdata}}, {id=> 'copyright', cdata => "--FIXME--"};

	my $package = {};
	$package->{id} = "default";
	$package->{name} = "$info->{module}";

	$package->{files}->{i} = [
				  '--FIXME--',
				 ];

	$package->{docs}->{i} = [
				 '--FIXME--',
				];

	$package->{description}->{h} = [
					"--FIXME-- short description of $info->{module}"
				       ];

	$package->{description}->{p} = [
					"--FIXME-- long description of $info->{module}"
				       ];

	$package->{psdata} = [];
	push @{$package->{psdata}}, {id=> 'group', cdata => "--FIXME--"};

	push @{$ts->{build}->{package}}, $package;

    }

    return $xml;

}

sub inspect_tarball {
    my $file = shift;
    my $info = {};

    my $filename = get_basename($file);

    ($info->{module}, $info->{version}) =
	@{Ximian::BB::XML::parse_version($filename)};

    my %dirs;
    if ($file=~ /\.t(ar\.)?gz$/){
        open TAR, "tar tvfz $file |";  # assumes GNU tar for now
    } else {
        open TAR, "tar -tv --use-compress-program=bzip2 -f $file |";
    }

    while (<TAR>) {
	s/^.*\s(\S+)$/$1/;  # this will break if the tarball contains
                            # filenames with whitespace

	s,\./,,; # some tarballs have e.g. ./Dir-1.2.3/ as the toplevel dir

	if (m,^[^/]+/Build\.PL$,) {  # perl Module::Build
	    $info->{module_build} = 1;
	} elsif (m,^[^/]+/Makefile\.PL$,) { # perl MakeMaker
	    $info->{makemaker} = 1;
	} elsif (m/^package.xml/) {  # check for a php module
	    $info->{php} = 1;
	}

	m,^([^/]+)/,;
	$dirs{$1} = 1 if not exists $dirs{$1};
    }
    close TAR;

    if (keys %dirs != 1) {
	print STDERR "warning: tarball doesn't contain a single toplevel directory\n";
    }

    my @dirs = keys %dirs;

    my $tardir = $dirs[0];

    if ($tardir ne "$info->{module}-$info->{version}") {
	print STDERR "setting tardir to $tardir\n";
	$info->{tardir} = $tardir;
    }

    if ($filename ne "$tardir.tar.gz") {
	print STDERR "setting tarname to $filename\n";
	$info->{tarname} = $filename;
    }

    return $info;
}

1;
