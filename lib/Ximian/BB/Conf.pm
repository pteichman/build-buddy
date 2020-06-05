package Ximian::BB::Conf;

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

# $Id: Conf.pm 3078 2005-12-22 22:06:32Z v_thunder $

use strict;
use Carp;

use Ximian::Util ':all';
use Ximian::BB::XMLUtil ':all';
use Ximian::BB::Macros ':all';
use Ximian::BB::Globals;
use Ximian::XML::Simple;

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
                  get_default_confdir
                  get_dir_literal
                  get_dir
                  parse_bb_conf
                  get_bb_conf
                  parse_os_conf
                  get_os_conf
		  parse_module_conf
		  get_module_conf
		  parse_project_conf
		  get_project_conf
                  parse_target_detect_conf
                  get_target_detect_conf
                  parse_snaps_conf
                  )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

# This is meant to be called at init time in the scripts to find
# either the compiled-in location, the checked-out development tree,
# or a location defined at runtime.  See the Ximian::BB::Globals
# module for more details.

sub get_default_confdir {
    my $confdir;
    foreach my $dir (($ENV{BB_CONFDIR},
                      @Ximian::BB::Globals::confdirs,
                      "$My::path/../conf")) {
        if (defined $dir and -d $dir and -f "$dir/bb.conf") {
            $confdir = $dir;
        }
    }
    unless ($confdir) {
        croak "Could not determine location of BB configuration files.";
    }
    return $confdir;
}

sub get_dir_literal {
    my $var = shift;
    my $confs = (shift() || $Ximian::BB::Globals::confs);
    reportline ({level=>4,nline=>0}, "Looking up directory for \"$var\" ... ");
    foreach my $conf (@$confs) {
        if ($conf->{dir}->{$var}) {
            my $dir = $conf->{dir}->{$var};
            report (4, "\"$dir\"\n\n");
            return $dir;
        }
    }
    reportline (4, "not found.");
    return "";
}

sub get_dir {
    my $var = shift;
    my $confs = (shift() || $Ximian::BB::Globals::confs);
    my $dir = macro_replace (get_dir_literal ($var, $confs));
    reportline (4, "Macro-replaced dir \"$var\": $dir") if $dir;
    return $dir;
}

######################################################################
# BB configuration files

sub parse_bb_conf {
    my ($filenames) = @_;
    my $conf = parse_xml_files ($filenames,
                                {forcearray => [qw(macro activate dirs dir)],
                                 targetsets => 0,
                                 lists => 0});
    reportline (3, "Parsed BB config");
    return $conf;
}

sub get_bb_conf {
    my $mainconf = @_;
    unless ($mainconf) {
        my $confdir = get_default_confdir ();
        $mainconf = "$confdir/bb.conf";
    }
    my $tmp = parse_bb_conf ([$mainconf]);
    my @confdirs = macro_replace ($tmp->{dirs}->{config}->{i}, [$tmp]);
    my @files = map {$_ .= "/bb.conf"} @confdirs;
    reportline (3, "Using BB configuration path \"@{[join ':', @files]}\"");
    return parse_bb_conf (\@files);
}

######################################################################
# Target detection file(s)

sub parse_target_detect_conf {
    my ($filenames) = @_;
    my $xml = parse_xml_files ($filenames,
                               {forcearray => [qw(macro activate dirs dir)],
                                targetsets => 0,
                                lists => 0});
    reportline (3, "Parsed target detection config");
    return $xml;
}

sub get_target_detect_conf {
    my (@confdirs) = @_;
    @confdirs = @Ximian::BB::Globals::confdirs unless (@confdirs);
    my @detectfiles = map {"$_/distro-detect.conf"} @confdirs;
    return parse_target_detect_conf (\@detectfiles);
}


######################################################################
# OS description file(s)
# FIXME: this says 'target', but it actually wants packsys:target
# TODO: should have conf validation steps for all of these

sub parse_os_conf {
    my ($filenames, $target) = @_;
    my $packsys = $Ximian::BB::Globals::packsys;
    my $tgt = $Ximian::BB::Globals::target;
    $target = ($target || "$packsys:$tgt");
    my $conf = parse_xml_files ($filenames,
                                {target => $target,
                                 forcearray => [qw(data path macro env dir)]});
    reportline (3, "Parsed OS config");
    return $conf;
}

sub get_os_conf {
    my ($target, @confdirs) = @_;
    @confdirs = @Ximian::BB::Globals::confdirs unless (@confdirs);
    unless ($target) {
        $target = "$Ximian::BB::Globals::packsys:$Ximian::BB::Globals::target";
    }
    my @osconfs = map {"$_/base.os.conf"} @confdirs;
    push @osconfs, map {"$_/os.conf"} @confdirs;
    return parse_os_conf (\@osconfs);
}

######################################################################
# Parse module-specific config file (build-buddy.conf)
# FIXME: this says 'target', but it actually wants packsys:target

sub parse_module_conf {
    my ($filename, $buildid, $target) = @_;
    my $packsys = $Ximian::BB::Globals::packsys;
    my $tgt = $Ximian::BB::Globals::target;
    $target = ($target || "$packsys:$tgt");
    $buildid = ($buildid || "default");
    my $conf = parse_xml_files ([$filename],
                                {target => $target,
                                 forcearray => [qw(macro dir build permissions package
                                                   dep builddep psdata script p)]});
    xml_merge ($conf->{build}->{$buildid}, $conf);
    delete $conf->{build};
    $conf->{srcname} = ($conf->{srcname} || $conf->{name});

    # fix parsing of <foo/>
    foreach my $field (qw/version revision rev serial/) {
        delete $conf->{$field} if $conf->{$field} and ishash $conf->{$field};
    }

    reportline (3, "Parsed module config");
    reportline (5, "Module config tree (buildid merged):", $conf);
    return $conf;
}

sub get_module_conf {
    return parse_module_conf (@_);
}

######################################################################
# Parse project config file (project.conf)
# FIXME: this says 'target', but it actually wants packsys:target

sub parse_project_conf {
    my ($filename, $target, $buildid) = @_;
    my $packsys = $Ximian::BB::Globals::packsys;
    my $tgt = $Ximian::BB::Globals::target;
    $target = ($target || "$packsys:$tgt");
    my $conf = parse_xml_files ([$filename],
                                {target => $target,
                                 forcearray => [qw(module dir service)]});
    $conf->{name} = ($conf->{name} || "project");
    reportline (3, "Parsed project config");
    reportline (5, "Project config tree:", $conf);
    return $conf;
}

sub get_project_conf {
    return parse_project_conf (@_);
}

######################################################################

# Parse snaps configuration file
#   parse_snaps_conf(opt => val, ...)
#   opts are:  debug (boolean)
#              conf_file (string)

sub parse_snaps_conf (%) {
    croak "Ximian::BB::Conf::parse_snaps_conf: Options must be name => value pairs"
	if (@_ % 2);
    my $opts = { @_ };

    my $conf_file = ($opts->{conf_file} || "snapshots.conf");
    unless ($conf_file =~ /^\//) {
        my $pwd = `pwd`;
        chomp $pwd;
        $conf_file = "$pwd/$conf_file";
    }

    my $conf = XMLin ($conf_file,
                      keyattr => [ qw(id) ],
                      forcearray => [ qw(snap module i) ],
                      contentkey => "cdata");

    return $conf;
}

1;

__END__
