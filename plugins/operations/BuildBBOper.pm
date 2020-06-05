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

#------------------------------------------------------------------------------
# Build operations
# These are the basic unpack/build operations
#------------------------------------------------------------------------------

package BuildBBOper;

use Ximian::Util ':all';
use Ximian::Run ':all';
use Ximian::BB::Globals;
use Ximian::BB::Conf ':all';

Ximian::BB::Plugin::register
    (name => "build",
     group => "operations",
     operations =>
     [
      { name => "module:unpack",
        module => \&module_unpack,
        description => "Unpacks a module and applies all patches." },

      { name => "module:unpack-unpatched",
        module => \&module_unpack_unpatched,
        description => "Unpacks a module without applying patches." },

      { name => "module:clean",
        module => \&clean,
        description => "Cleans a module directory.  Opposite of 'unpack'" },

      { name => "bb_do",
        module => \&bb_do,
        description => "Perform all bb_do operations in order." },

      { name => "bb_do:dist",
        module => \&bb_do_dist,
        description => "Does all preparatory work necessary for the " .
            "package system backend." },

      { name => "bb_do:source",
        module => \&bb_do_source,
        description => "Generates a source package." },

      { name => "bb_do:prepare",
        module => \&bb_do_prepare,
        description => "Performs all preparatory steps necessary to be " .
	      		     "able to compile the module." },

      { name => "bb_do:clean",
        module => \&bb_do_clean,
        description => "Attempts to return the build directory to a " .
            "pristine state." },

      { name => "bb_do:build",
        module => \&bb_do_build,
        description => "Compiles or otherwise create the files which " .
            "will be included in the final package." },

      { name => "bb_do:instpack",
        module => \&bb_do_instpack,
        description => "Install files and create binary packages." },

      { name => "bb_do:install",
        module => \&bb_do_install,
        description => "Install files to be packed into binary packages " .
            "to a temporary directory." },

      { name => "bb_do:pack",
        module => \&bb_do_pack,
        description => "Create binary packages." },
      ],
# FIXME: add lint and install to default op once it's working again
     tasks =>
     [
      { name => "build",
        operations => [ "rcd:module-deps",
                        "module:clean", "module:unpack", "bb_do" ],
        description => "Default task.  " .
            "Makes a package from scratch and installs it." },
      ]);

#------------------------------------------------------------------------------

sub clean {
    my ($module, $data) = @_;
    my $conf = $module->{conf};
    reportline (2, "bb_build (clean): Running clean on: $module->{name}");
    return run_cmd ("bb_unpack -v $data->{verbosity} clean");
}

sub module_unpack {
    my ($module, $data, $unpatched) = @_;
    my $conf = $module->{conf};
    $unpatched = $unpatched? "-p none" : "";
    my $ts = gmtime ($data->{timestamp}) . " GMT";
    reportline (2, "bb_build (unpack): Running unpack on: $module->{name}");
    return run_cmd ("bb_unpack -v $data->{verbosity} $unpatched -g \"$ts\" get apply");
}

sub module_unpack_unpatched {
    my ($module, $data) = @_;
    my $conf = $module->{conf};
    return module_unpack ($module, $conf, $data, "unpatched");
}

sub bb_do {
    my ($module, $data, $oper) = @_;
    $oper = "" unless defined $oper;
    my $conf = $module->{conf};
    my $adir = "--archivedir '$data->{archivedir}' " .
        "--src_archivedir '$data->{src_archivedir}'";
    my $bid = ($data->{build_id} || $module->{build_id} || "");
    $bid = "-b '$bid'" if $bid;
    reportline (2, "bb_build (bb_do): Running bb_do on: $module->{name}");
    return run_cmd ("bb_do -v $data->{verbosity} $adir $bid $oper");
}

sub bb_do_dist { return bb_do (@_, "dist"); }
sub bb_do_source { return bb_do (@_, "source"); }
sub bb_do_prepare { return bb_do (@_, "prepare"); }
sub bb_do_clean { return bb_do (@_, "clean"); }
sub bb_do_build { return bb_do (@_, "build"); }
sub bb_do_instpack { return bb_do (@_, "install pack"); }
sub bb_do_install { return bb_do (@_, "install"); }
sub bb_do_pack { return bb_do (@_, "pack"); }

1;
