package Ximian::BB::Macros;

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
use POSIX; # for getcwd

use Ximian::Util ':all';
use Ximian::BB::Globals;
#use Ximian::BB::XMLUtil ':all';

# $Id: Conf.pm,v 1.115 2005/09/14 23:03:52 v_thunder Exp $

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
		  macro_replace
                  )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

sub helper {
    my $foo = shift;
    reportline ({level=>5,tstamp=>0}, $foo);
    return $foo;
}

# Replace '[[MACRO]]' in arg string with macros defined in
# $distro_info and $package_system_info, replace {{ENV}} with the
# associated environment variable, and return substituted
# result.

sub find_replacement {
    my ($var, $confs, $packsys, $target) = @_;

    report (5, "Looking up macro \"$var\"...");

    if ($var eq 'packsys') {
	return helper  $packsys;
    } elsif ($var eq 'target') {
	return helper $target;
    } elsif ($var eq 'pwd') {
	return helper getcwd; # Yech!
    }

    foreach my $t (qw/macro data dir/) {
        foreach my $conf (@$confs) {
            if (ref $conf->{$t}->{$var} and defined $conf->{$t}->{$var}->{content}) {
                return helper ($conf->{$t}->{$var}->{content});
            } elsif (defined $conf->{$t}->{$var}) {
                return helper ($conf->{$t}->{$var});
            }
        }
    }
    foreach my $conf (@$confs) {
        return helper ($conf->{$var}) if defined $conf->{$var};
    }

    if ($var eq 'bb_basedir' and defined $My::path) {
        if (-f "$My::path/../BB.pm") {
            return helper "$My::path/..";
        } else {
            # FIXME: we need multiple paths, bb_basedir doesn't cut it in the installed case
            reportline (1, "Warning: bb_basedir macro cannot be used when BB is installed.");
            return "/usr/share/build-buddy"; # lame attempt
        }
    }

    reportline (5, "not found.");
    return "";
}

sub macro_replace {
    my $str  = shift;
    my $confs = shift() || $Ximian::BB::Globals::confs;
    my $packsys = shift() || $Ximian::BB::Globals::packsys;
    my $target = shift() || $Ximian::BB::Globals::target;
    my $seen = shift() || {};

    unless (defined $str) {
	reportline (1, "Warning: macro_replace called with an undefined string.");
	return "";
    }

    if (isarray $str) {
        my @ret;
        foreach my $i (@$str) {
            push @ret, macro_replace ($i, $confs, $packsys, $target);
        }
        return @ret;
    }

    $str =~ s/\{\{(\w+)\}\}/$ENV{$1} || ''/eg;

    my @matches = $str =~ m/\[\[(\w+)\]\]/g;
    foreach my $match (@matches) {
	if (exists $seen->{$match}) {
	    reportline (1, "macro replacement error: loop detected on [[$match]]");
	    return undef;
	}

	my %newseen = %$seen;
	$newseen{$match} = 1;

	my $replace = find_replacement($match, $confs, $packsys, $target);
	my $replaced = macro_replace($replace, $confs, $packsys, $target, \%newseen);
	if (not defined $replaced) {
	    reportline (1, "  [[$match]]: $replace");
	    return undef;
	}
	$str =~ s/\[\[$match\]\]/$replaced/;
    }
    return $str;
}

1;

__END__
