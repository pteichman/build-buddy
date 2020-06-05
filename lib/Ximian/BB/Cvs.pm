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

package Ximian::BB::Cvs;

# this file is not called CVS.pm, because MakeMaker ignores CVS*

use strict;

use Ximian::BB::Logger ':all';
use Ximian::Util ':all';

sub get_module {
    my ($session, $starttime, $module) = @_;
    die "No module name specified." unless $module->{name};
    die "No cvsroot specified" unless $module->{cvsroot};
    my $moduledir = ($module->{cvsmodule} || "unknown");
    my $rev = $module->{cvsversion}? "-r $module->{cvsversion}" : "";

    if ($module->{cvsroot} =~ /^svn/) {
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = gmtime($starttime);
        my $time = sprintf("-r {\"%04d-%02d-%02d %02d:%02d:%02d +00\"}",
                           $year + 1900, $mon, $mday, $hour, $min, $sec);
        $rev = $rev? $rev : $time;
        $session->run_cmd ({name => "module-checkout:mkdir-$moduledir"},
                           "mkdir -p $moduledir")
            && die "Could not check out $module->{name}.\n";
        $session->run_cmd ({name => "module-checkout:$module->{name}"},
	                   "cd $moduledir; svn checkout $rev " .
		           "$module->{cvsroot}/$module->{name}")
            && die "Could not check out $module->{name}.\n";
    } else {
        my $time = $starttime? "-D \"" . gmtime ($starttime) . "GMT\"" : "";
        $session->run_cmd ({name => "module-checkout:$module->{name}"},
	                   "cvs -d $module->{cvsroot} co $time $rev " .
		           "$moduledir/$module->{name}")
            && die "Could not check out $module->{name}.\n";
    }
    return 1;
}

1;
