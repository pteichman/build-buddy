package Ximian::BB::XMLUtil;

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

use Ximian::Util ':all';
use Ximian::XML::Simple;
use Storable qw/dclone/;

# $Id:  $

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(xml_merge
                  xml_list_merge
                  xml_targetset_merge
                  filter_match
                  parse_xml_files
                  )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

# Merge two hash/array subtrees, with contents of $src overriding
# $dst.  This isn't really "xml" specific, but we use it almost
# exclusively to merge XML::Simple::XMLin output

sub xml_merge {
    my ($src, $dst) = @_;
    if (ishash $src) {
	if (keys %$src) {
	    foreach my $tag (keys %$src) {
		if (ref $src->{$tag}) {
                    if (ref $dst->{$tag}) {
                        xml_merge($src->{$tag}, $dst->{$tag});
                    } else {
                        $dst->{$tag} = dclone $src->{$tag};
                    }
		} else {
		    $dst->{$tag} = $src->{$tag};
		}
	    }
	} else {
	    %$dst = ();
	}
    } elsif (isarray $src) {
	if (@$src) {
	    $#$dst = $#$src;
	    for my $i (0 .. $#$src) {
		if (ref $src->[$i]) {
                    if (ref $dst->[$i]) {
                        xml_merge ($src->[$i], $dst->[$i]);
                    } else {
                        $dst->[$i] = dclone $src->[$i];
                    }
		} else {
		    $dst->[$i] = $src->[$i];
		}
	    }
	} else {
	    @$dst = ();
	}
    }
}

sub cycle_check {
    my ($lists) = @_;
    foreach my $l (keys %$lists) {
        cycle_check_single ($lists, $l);
    }
}

sub cycle_check_single {
    my ($all_lists, $list, $init, $parent) = @_;
    $init = ($init || $list);

    return if exists $all_lists->{$list}->{"cycle-check-ok"};

    if ($all_lists->{$list}->{"cycle-check-tmp"}) {
        croak "Error processing lists: loop found:\n" .
            "\"$init\" -> ... -> \"$parent\" -> \"$list\"\n";
    }
    $all_lists->{$list}->{"cycle-check-tmp"} = 1;
    foreach my $child (@{$all_lists->{$list}->{l}}) {
	cycle_check_single ($all_lists, $child, $init, $list);
    }
    $all_lists->{$list}->{"cycle-check-ok"} = 1;
}

# Merge in the contents of a referenced list (through <l>) into an <i> list

sub merge_list {
    my ($xml, $lists) = @_;

    return unless defined $xml->{l};
    my $l_elts = $xml->{l};

    $xml->{i} = [] if not $xml->{i};
    my $i_elts = $xml->{i};

    for my $n (0 .. $#$l_elts) {
	my $srclist = $lists->{$$l_elts[$n]}->{i};

	for my $p (0 .. $#$srclist) {
	    push @$i_elts, $$srclist[$p];
	}
	undef $$l_elts[$n];
	if (0 == $#$l_elts) {
	    undef $xml->{l};
	}
    }
    delete $xml->{l};
}

sub find_listrefs {
    my ($xml, $lists) = @_;

    if (ishash $xml) {
	if (keys %$xml) {
	    foreach my $tag (keys %$xml) {
		if ($tag eq "l") {
		    merge_list ($xml, $lists);
		} elsif (ref $xml->{$tag}) {
		    find_listrefs ($xml->{$tag}, $lists);
                }
	    }
	}
    } elsif (isarray $xml and scalar @$xml) {
	for my $i (0 .. $#$xml) {
            if (ref $xml->[$i]) {
                find_listrefs ($xml->[$i]);
            }
            # note: we don't support <l> elts in an array
        }
    }
}

sub xml_list_merge {
    my ($xml) = @_;

    cycle_check ($xml->{list});

    # Flatten the lists
    foreach my $list (keys %{$xml->{list}}) {
	merge_list ($xml->{list}->{$list}, $xml->{list});
    }

    find_listrefs ($xml, $xml->{list});
    delete $xml->{list};
}

sub xml_targetset_merge {
    my ($xml, $target) = @_;

    foreach my $targetset (@{$xml->{targetset}}) {
	if (filter_match ($target, $targetset->{filter})) {
	    xml_merge ($targetset, $xml);
	}
    }

    # to avoid confusion:
    delete $xml->{targetset};
    delete $xml->{filter};
}

# Match an id against a filter list.
# Return true (1) if it matches, and false (0) otherwise.
#   Ximian::BB::Conf::filter_match ($packsys, $targetid, $filter_section)
#   * If first character in a filter element is '!', return false even
#     if it matches.
#   * If packsys is given, prepend it to the id as "packsys:id",
#     otherwise perform the match against the id alone.

sub filter_match ($$$) {
    my ($id, $filter) = @_;
    
    foreach my $target (reverse @{$filter->{i}}) {
	if ($target =~ /^!/) {
	    my $tgt = substr($target,1);
	    return 0 if ($id =~ /$tgt/);
	} else {
	    return 1 if ($id =~ /$target/);
	}
    }
    return 0;
}

# Read in and merge/flatten XML files
# FIXME: this says 'target', but it actually wants packsys:target

sub parse_xml_files {
    my ($filenames, $opts) = @_;
    my $xml = {};

    my $targetsets = first_defined ($opts->{targetsets}, 1);
    my $decl = first_defined ($opts->{decl}, 1);
    my $lists = first_defined ($opts->{lists}, 1);
    my $target = first_defined ($opts->{target}, "unknown");

    my @forcearray = ();
    push @forcearray, qw(targetset) if $targetsets;
    push @forcearray, qw(list l i) if $lists;
    push @forcearray, @{$opts->{forcearray}};

    foreach my $filename (@$filenames) {
        reportline (7, "XML read: trying file \"$filename\"");
        next unless -f $filename;
        eval {
            my $tmp = XMLin ($filename,
                             keyattr => [ qw(id) ],
                             forcearray => \@forcearray,
                             contentkey => '-content');
            reportline (6, "Raw XML tree ($filename):", $tmp);

            if ($targetsets) {
                xml_targetset_merge ($tmp, $target);
                reportline (7, "XML tree, targetsets merged ($filename):", $tmp);
            }

            if ($decl and exists $tmp->{decl}) { # for backward compatibility
                xml_merge ($tmp->{decl}, $tmp);
                delete $tmp->{decl};
                reportline (7, "XML tree, decl merged ($filename):", $tmp);
            }
            xml_merge ($tmp, $xml);
        };
        if ($@) {
            croak "Error loading XML file ($filename): $@";
        }
    }
    if ($lists) {
        xml_list_merge ($xml);
    }
    reportline (6, "Parsed XML:", $xml);
    return $xml;
}

1;

__END__
