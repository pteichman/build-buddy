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

package Ximian::BB::JailUtil;

=head1 NAME

B<Ximian::BB::JailUtil> - Useful routines for dealing with Jail objects

=head1 DESCRIPTION

This is a collection of routines for dealing with Ximian::BB::Jail
objects.

=head1 SYNOPSIS

    use Ximian::BB::Jail;
    use Ximian::BB::JailUtil ':all';

    my @jails = Ximian::BB::Jail->load_guess_multiple (dir => "/jails");

    # get a list of all targets available
    my @targets = jail_unique_targets (@jails);

    # match if main metadata (main.xml) has <target>peteros-14-i386</target>
    my @with_peteros = jail_grep (key => "target",
                                  val => "peteros-14-i386",
                                  jails => \@jails);

    # match if check_metadata returns 1
    my @special = jail_grep (sub => sub { return check_metadata (shift) },
                             metadata_id => "special",
                             jails => \@jails);

=cut

use strict;

use FindBin;
use Ximian::Util ':all';
use Ximian::BB::Conf ':all';

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
                  jail_grep
                  jail_unique_targets
		  jail_search_target
                  )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

########################################################################

=head1 EXPORTED SUBROUTINES

=head2 jail_grep (key => value, ...)

Search through the metadata of jails and return matching ones.
Options are:

=over 4

=item jails

Required argument.  Listref of jails to search through.

=item key

Metadata tag to look in.

=item value

Value the metadata tag should have for the jail to match.

=item metadata_id

Metadata file to look in.  "main" is the default.

=item sub

A subroutine reference to be run for each jail.  It is given the
metadata object as its single argument.  If the subroutine returns
true, the jail matches and is included in the list.  Note that if this
option is given, key and val are ignored.

=back

=cut

sub jail_grep {
    die "Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    die "No jails given" unless $opts->{jails};
    my $metadata_id = ($opts->{metadata_id} || "main");

    my @matches;
    foreach my $jail (@{$opts->{jails}}) {
	my $meta = eval {$jail->get_metadata ($metadata_id)};
	next if $@;
	if ($opts->{sub}) {
	    push @matches, $jail
		if $opts->{sub}->($meta);
	} elsif ($opts->{xpath}) {
	    die "No text to search for." unless $opts->{text};
	    my $xpath = $meta->get_xpath_obj;
	    my $xp_matches = $xpath->find ($opts->{xpath});
	    if ($xp_matches->isa ("XML::XPath::NodeSet")) {
		my $found = 0;
		foreach my $node ($xp_matches->get_nodelist) {
		    $found = 1
			if $node->string_value eq $opts->{text};
		}
		next unless $found;
	    } else {
		next unless $xp_matches eq $opts->{text};
	    }
	    push @matches, $jail;
	} elsif ($opts->{key}) {
	    die "No text to search for." unless $opts->{text};
	    my $tree = $meta->get_xml_tree;
	    next unless $tree->{$opts->{key}};
	    next unless $tree->{$opts->{key}} eq $opts->{text};
	    push @matches, $jail;
	} else {
	    die "Malformed grep query";
	}
    }
    return @matches;
}

=head2 jail_unique_target (@jails)

Extracts the exported targets from all the given jails, and returns a
list of them, where each target is listed only once.

=cut

sub jail_unique_targets {
    my @tgts;
    foreach (@_) {
	my $meta = eval {$_->get_metadata_tree ("main")};
	next if $@;
	next unless $meta->{target};
	next if member_str $meta->{target}, @tgts;
	push @tgts, $meta->{target};
    }
    return @tgts;
}

=head2 jail_search_target ($dir, $target)

Loads all jails in $dir, greps for the jails that export $target, and
returns them.

=cut

sub jail_search_target {
    my ($dir, $target) = @_;
    my @jails =	Ximian::BB::Jail->load_guess_multiple (dir => $dir);
    my @matches = jail_grep (key => "target", text => $target, jails => \@jails);
#    die "Target \"$target\" not available.\n" unless scalar @matches;
    return @matches;
}

########################################################################


1;

__END__

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
