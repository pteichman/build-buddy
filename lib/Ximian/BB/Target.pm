package Ximian::BB::Target;

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
use File::Path;

use Ximian::Util ':all';
use Ximian::BB::Conf ':all';

# $Id:  $

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
                  detect_target
                  )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

sub detect_target {
    my (@filenames) = @_;
    my $conf = get_target_detect_conf (@filenames);
    my $guess = guess_string ();
    reportline (5, "Distro guess: \"$guess\"");

    foreach my $target (keys %{$conf->{target}}) {
        my $re = $conf->{target}->{$target}->{re};
        reportline (5, "Distro detect: Checking regex \"$re\"");
        if ($guess =~ /$re/) {
            my $packsys = $conf->{target}->{$target}->{packsys};
            reportline (3, "Detected target $packsys:$target");
            return ($packsys, $target);
        }
    }
    croak "Distribution \"$guess\" is not supported.  Check distro detection config file(s).\n";
}

sub guess_string {
    my $guess;

    # config.guess needs write permissions in the current directory
    my $tmp = make_temp_dir;
    pushd $tmp;
    $guess = `config.guess`;
    if ($? >> 8) {
        reportline (1, "Could not run config.guess ($!).",
                    "Please ensure it is in the PATH.");
        croak "Could not run config.guess\n";
    }
    chomp ($guess);
    popd;
    rmtree $tmp if -d $tmp;

    # If config.guess tells us it's Linux, we need to figure out which
    # distribution it is.
    if ($guess =~ /linux-gnu(oldld)?$/) {

        # Note: Red Hat checks must run last, because
        # some other distros have /etc/redhat-release too
        my @checks = (\&check_debian,
                      \&check_caldera,
                      \&check_suse,
                      \&check_mandrake,
                      \&check_playstation,
                      \&check_linuxppc,
                      \&check_yellowdog,
                      \&check_turbolinux,
                      \&check_fedora,
                      \&check_redhat_el,
                      \&check_redhat);
        my $distro;
        foreach my $c (@checks) {
            if ($distro = $c->()) {
                $guess .= "-$distro";
                last;
            }
        }
        unless ($distro) {
            reportline (1, "Warning: Linux detected, but could not determine distribution.");
        }
    }
    return $guess;
}

sub check_debian {
    my ($distribution, $version);
    open DEBIAN, "/etc/debian_version" or return 0;
    $distribution = 'debian';
    chomp ($version = <DEBIAN>);
    close DEBIAN;
    return "$distribution-$version";
}

sub check_redhat {
    my ($distribution, $version);
    open RELEASE, "/etc/redhat-release" or return 0;
    $distribution = 'redhat';
    while (<RELEASE>) {
	chomp;
	if (/^Red Hat Linux.*\s+([0-9.]+)\s+.*/) {
	    $version = $1;
	    close RELEASE;
            return "$distribution-$version";
	}
    }
    close RELEASE;
    return 0;
}

sub check_redhat_el {
    my ($distribution, $version);
    open RELEASE, "/etc/redhat-release" or return 0;
    $distribution = 'rhel';
    while (<RELEASE>) {
	chomp;
        if (/^Red Hat Enterprise Linux\s+([WEAS]+)\s+release\s+(\d+)/) {
	    $version = "$2$1";
	    close RELEASE;
            return "$distribution-$version";
	} elsif (/^Red Hat Enterprise Linux.*\s+([0-9.WEAS]+)/
		 or /^Red Hat Linux Advanced Server.*\s+([0-9.AS]+)/) {
	    $version = $1;
	    close RELEASE;
            return "$distribution-$version";
	}
    }
    close RELEASE;
    return 0;
}

sub check_fedora {
    my ($distribution, $version);
    open RELEASE, "/etc/fedora-release" or return 0;
    $distribution = 'fedora';
    while (<RELEASE>) {
	chomp;
	if (/^Fedora Core release\s+([0-9.]+)/) {
	    $version = $1;
	    close RELEASE;
            return "$distribution-$version";
	}
    }
    close RELEASE;
    return 0;
}

sub check_caldera {
    my ($distribution, $version);
    open INSTALLED, "/etc/.installed" or return 0;
    while (<INSTALLED>) {
	chomp;
	if (/^OpenLinux-(.*)-.*/) {
	    $distribution = 'caldera';
	    $version = $1;
	    close INSTALLED;
            return "$distribution-$version";
	}
    }
    close INSTALLED;
    return 0;
}

sub check_suse {
    my ($distribution, $version);
    open RELEASE, "/etc/SuSE-release" or return 0;
    while (<RELEASE>) {
	chomp;
	if (/^SuSE (SLES|SLEC)-([0-9.]+)/) {
	    $distribution = lc($1);
	    $version = $2;
	} elsif (/^SuSE Linux Desktop ([0-9.]+)/) {
	    $distribution = "sld";
	    $version = $1;
	} elsif (/^Novell Linux Desktop ([0-9.]+)/) {
	    $distribution = "nld";
	    $version = $1;
	} elsif (/^SUSE LINUX Enterprise Server ([0-9.]+)/) {
	    $distribution = "sles";
	    $version = $1;
        } elsif (not defined $version and /^VERSION\s*=\s*(\S+)/) {
	    $distribution = "suse";
	    $version = $1;
	}
    }
    close RELEASE;
    return "$distribution-$version" if $distribution and $version;
    return 0;
}

sub check_mandrake {
    my ($distribution, $version);
    open MANDRAKE, "/etc/mandrake-release" or return 0;
    $distribution = 'mandrake';
    while (<MANDRAKE>) {
	chomp;
	if (/^Linux Mandrake release (\S+)/) {
	    $version = $1;
	    close MANDRAKE;
            return "$distribution-$version";
	}
	if (/^Mandrake Linux release (\S+)/) {
	    $version = $1;
	    close MANDRAKE;
            return "$distribution-$version";
	}
    }
    close MANDRAKE;
    return 0;
}

sub check_playstation {
    my ($distribution, $version);
    open PS2, "/etc/ps2-release" or return 0;
    $distribution = 'ps2';
    while (<PS2>) {
	chomp;
	if (/^PS2 Linux release (\S+)/) {
	    $version = $1;
	    close PS2;
            return "$distribution-$version";
	}
    }
    close PS2;
    return 0;
}

sub check_turbolinux {
    my ($distribution, $version);
    open RELEASE, "/etc/turbolinux-release" or return 0;
    $distribution = 'turbolinux';
    while (<RELEASE>) {
	chomp;
	if (/release\s([0-9.]+)\s.*/) {
	    $version = $1;
	    close RELEASE;
            return "$distribution-$version";
	}
    }
    close RELEASE;
    return 0;
}

sub check_linuxppc {
    my ($distribution, $version);
    open RELEASE, "/etc/redhat-release" or return 0;
    while (<RELEASE>) {
	chomp;
	if (/^LinuxPPC\s+(\S+)/) {
	    $distribution = 'linuxppc';
	    $version = $1;
	    close RELEASE;
            return "$distribution-$version";
	}
	if (/^Linux\/PPC\s+(\S+)\s+(\S+)/) {
	    $distribution = 'linuxppc';
	    $version = "${1}${2}";
	    close RELEASE;
            return "$distribution-$version";
	}
    }
    close RELEASE;
    return 0;
}

sub check_yellowdog {
    my ($distribution, $version);
    open RELEASE, "/etc/yellowdog-release" or return 0;
    while (<RELEASE>) {
        chomp;
        if (/^Yellow Dog Linux release\s+(\S+)/) {
            $distribution = 'yellowdog';
            $version = $1;
            close RELEASE;
            return "$distribution-$version";
        }
    }
    close RELEASE;
    return 0;
}

1;

__END__
