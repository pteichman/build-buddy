# Copyright 2004 Ximian, Inc.
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

package OpenCarpetBBOper;

use Cwd;

use Ximian::Run ':all';
use Ximian::Util ':all';
#use Ximian::Packsys ':all';
use Ximian::BB::Snapshot ':all';

my %args;
parse_args (\%args,
	    [
	     {names => ["opencarpet_channel"], type => "=s", default => ""},
	     {names => ["opencarpet"],         type => "=s", default => ""},
	    ]);

sub get_operations {
    return [
	    { name => "opencarpet:release",
	      description => "Submit a package to a Red Carpet (Open Carpet) channel.",
	      run => [ 0 , 'opencarpet_copy', 'opencarpet_finish' ] },
	   ];
}

sub opencarpet_copy {
    my ($module, $conf, $data) = @_;

    # Munge version in $conf if this is a snapshot run
    # It might be best to move this to bb_build..
    # Copied from InstallBBOper.pm
    if ($module->{snapshot}) {
	$conf->{version} = snapshot_cvs_version ($module, $conf,
						 $data->{timestamp}, $data->{packsys});
	return 1 unless (defined $conf->{version});
    }
    my @pkgs = @{get_package_files ($conf, $data->{target}, undef, $module->{snapshot})};
    my @files = map {"$data->{archivedir}/$_"} @pkgs;

    eval {
	foreach (@files) {
	    #FIXME: should probably use 'install' instead of 'cp'
	    run_cmd ("cp $_ $args{opencarpet}/$args{opencarpet_channel}/$data->{target}")
		&& die "Could not cp package to $args{opencarpet}";
	}
    };
    return 0;
}

sub opencarpet_finish {
  my ($module, $conf, $data) = @_;

  run_cmd ("open-carpet $args{opencarpet}")
      && die "Could not refresh opencarpet repository";
}

1;
