package Ximian::BB::Event;

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

use strict 'vars';

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(event_attach event_fire);

my %events;

use Data::Dumper;

sub event_attach {
    my ($event, $callback, $data) = @_;

    my $handler = {'callback' => $callback,
		   'closure'  => $data};

    $events{$event} = [] unless exists $events{$event};
    push @{$events{$event}}, $handler;
}

sub dispatch {
    my ($name, $handlers, $data) = @_;

    return unless defined $handlers;

    foreach my $handler (@$handlers) {
	my $callback = $handler->{'callback'};
	my $closure  = $handler->{'closure'};

	&$callback($name, $data, $closure);
    }
}

sub event_fire {
    my ($event, $arg) = @_;

    dispatch ($event, $events{$event}, $arg);
    dispatch ($event, $events{'all'},  $arg);
}

1;
