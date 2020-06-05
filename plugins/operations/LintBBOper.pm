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

package LintBBOper;

use strict;
use Cwd;
use Ximian::Util ':all';
use Ximian::Run ':all';
use Ximian::BB::Snapshot ':all';

sub get_operations {
    return [
            { name => "lint:prebuild",
              description => "Run the bb_lint prebuild checks",
              run => [ 0 , 'lint_prebuild', 0 ] },
            { name => "lint:all",
              description => "Run all bb_lint tests",
              run => [ 0 , 'lint', 0 ] },
           ];
}

#------------------------------------------------------------------------------

sub lint_prebuild {
    my ($module, $conf, $data) = @_;
    return run_cmd ("bb_lint -g prebuild");
}

sub lint {
    my ($module, $conf, $data) = @_;
    my $options = "";

    if ($module->{snapshot}) {
	my $ver = snapshot_cvs_version ($module, $conf,
					$data->{timestamp}, $data->{packsys});
	return 1 unless (defined $ver);
	$options = "-V '$ver' -R '0.snap'";
    }
    return system ("bb_lint $options");
}

1;
