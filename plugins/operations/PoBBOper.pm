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

package PoBBOper;

use strict;
use Ximian::Util ':all';
use Ximian::Run ':all';
use Ximian::BB::Conf ':all';

sub get_operations {
    return [
            { name => "po:get-po",
              description => "Get po file(s) from the module",
              run => [ 'get_po_init' , 'get_po_module', 'get_po_finish' ] },
           ];
}

#------------------------------------------------------------------------------

my $tmpdir;

my %args;
parse_args
    (\%args,
     [
      {names => ["pofiles"], type => "=s", default => ""},
      {names => ["podir"  ], type => "=s", default => "po"},
      {names => ["tarball"], type => "=s", default => "pofiles.tar.gz"},
     ]);

# add .po and .pot files for each language passed in
my @pofiles = grep { $_ .= ".po" } split /[\s,]+/, $args{pofiles};

#------------------------------------------------------------------------------

sub get_po_init {
    my ($module, $conf, $data) = @_;
    $tmpdir = make_temp_dir ();
    run_cmd ("mkdir $tmpdir/po-files") && return 1;
    $tmpdir .= "/po-files";
    return 0;
}

sub log_error {
    my $module = shift;
    open LOG, ">>$tmpdir/pofiles.log"
	or die "Could not open log file: $!.";
    print LOG " ($module): $_\n" foreach (@_);
    close LOG;
    return 0; # "false" for use in grep
}

sub prep_conf {
    my ($conf) = @_;
    $conf->{srcname} = $conf->{name} unless defined $conf->{srcname};
    Ximian::BB::Conf::macro_replace ($conf->{srcname});

    $conf->{tardir} = "$conf->{srcname}-$conf->{version}"
	unless defined $conf->{tardir};
    Ximian::BB::Conf::macro_replace ($conf->{tardir});
}

sub get_po_module {
    my ($module, $conf, $data) = @_;

    prep_conf ($conf);

    my $podir = "BUILD/$conf->{tardir}/$args{podir}";
    my @files = @pofiles; # per-module copy

    if (scalar @files) {
	# Take out any pofiles that don't exist (and log errors)
	my ($m, $nm) = twogrep { -f "$podir/$_" } @files;
	@files = @$m;
	log_error $module->{name}, "$podir/$_ not found." foreach (@$nm);

	# Add any pot file(s)
	push @files, dirgrep { /\.pot$/ } $podir
	    or log_error $module->{name}, "No pot file found";
	return unless scalar @files;
    } else {
	# If no po files were passed in, make a list of all the po files
	@files = dirgrep { /\.pot?$/ } $podir
	    or return log_error $module->{name}, "Could not open podir.";
    }

    # Now, copy the pofiles into place, and return
    pushd $podir;
    run_cmd ("make update-po")
	&& log_error $module->{name}, "Error running \"make update-po\".";
    run_cmd ("mkdir $tmpdir/$module->{name}")
	&& die "Could not make dir \"$tmpdir/$module->{name}\": $!";
    foreach my $file (@files) {
	run_cmd ("cp $file $tmpdir/$module->{name}")
	    && die "Error copying pofile: $!.";
    }
    popd;

    return 0;
}

sub get_po_finish {
    my ($module, $conf, $data) = @_;
    print "Tmpdir is: $tmpdir\n";
    pushd "$tmpdir/..";
    run_cmd ("tar cvf - po-files | gzip > $args{tarball}")
	&& die "Could not create tarball: $!";
    popd;
    run_cmd ("cp $tmpdir/../$args{tarball} .")
	&& die "Could not copy tarball: $!";
    print "Tarball is: $args{tarball}\n";
    return 0;
}

1;
