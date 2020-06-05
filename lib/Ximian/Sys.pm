package Ximian::Sys;

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

# $Id: Sys.pm 3068 2005-12-22 03:41:13Z v_thunder $

use strict;
use Socket;

use Ximian::Util ':all';

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
                  disk_usage
                  cpu_usage
                  find_port
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

sub disk_usage {
    my ($path) = @_;
    return undef unless defined $path;
    my ($free, $total);

    # Temporarily set the language to the default (english)
    local $ENV{LANG} = "C";

    # First, we find out how we need to run df:
    # GNU df will split long lines into two unless the -P
    # option is given.  Unfortunately, Solaris/BSD df error
    # out if the -P option is used.

    open DF, "df -P 2>&1 |" or return undef;
    my $line = <DF>;
    close DF;

    my $df = "df -Pk";
    $df = "df -k" if ($line =~ /(illegal|unknown) option/);

    open DF, "$df $path |" or return undef;
    while (<DF>) {
	next unless m/^\//;
	if (m/^\S+\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+%)\s+(\S+)$/) {
	    # Return amounts in bytes:
	    $total = $1 * 1024;
	    $free  = $3 * 1024;
	}
    }
    close DF;
    return {free => $free, total => $total};
}

sub cpu_usage {
    # Temporarily set the language to the default (english)
    local $ENV{LANG} = "C";

    chomp (my $uptime = `uptime`);
    $uptime =~ s/.*load average:\s+//;
    return split (/,\s+/, $uptime);
}

sub find_port {
    my $port = shift;

    lock_acquire ("/tmp/acquire_port");

    my $returnport = -1;
    my $topport = $port + 100;
    my $proto = getprotobyname('tcp');

    while ($port < $topport && $returnport == -1) {
        socket(SOCKET, PF_INET, SOCK_STREAM, $proto) || die "socket: $!";
        setsockopt(SOCKET, SOL_SOCKET, SO_REUSEADDR, pack ("l", 1)) || die "$!";
        if (bind(SOCKET, sockaddr_in($port, INADDR_ANY))) {
            $returnport = $port;
            close (SOCKET);
        }
        $port++;
    }
    lock_release ("/tmp/acquire_port");
    return $returnport;
}

1;

__END__

=pod

=head1 NAME

Ximian::Sys - Perl interface to some system functions

=head1 SYNOPSIS

use Ximian::Sys;

my ($free, $total) = disk_usage("/");

my ($avg15, $avg10, $avg1) = cpu_usage();

my $port = find_port(20000);

=head1 DESCRIPTION

Ximian::Sys provides a perl interface to a few libc functions needed
by the build system and related tools.  It wraps statfs() and
getloadavg().

find_port returns the next available port on the system greater than
its argument.
