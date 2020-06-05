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

package Ximian::BB::Jail::Metadata;

=head1 NAME

B<Ximian::BB::Jail::Metadata> - XML-Backed Jail Metadata Object

=head1 DESCRIPTION

A very simple wrapper around XML::Simple that adds a standardized
save/load/reload functionality for used in jail objects.  Its
usefulness is to allow easy (human-editable) configuration files that
will be stored inside the jail.

Note that this metadata object does not derive from
Ximian::BB::Jail::Serializable, so rather than deriving from this
class, derive from Ximian::BB::Jail::Serializable, and
store/load/reload one of these objects.

=head1 SYNOPSIS

    use Ximian::BB::Jail::Metadata;

=cut

use strict;
use File::Spec::Functions 'rel2abs';
use XML::XPath;

use Ximian::Util ':all';

########################################################################

=head1 CLASS METHODS

=head2 new

=head2 load

=cut

sub new {
    my $class = shift;
    die "new: Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    my $self = bless {}, $class;
    $self->{path} = rel2abs ($opts->{path}) or die "No path given.";
    $self->reload (@_);
    return $self;
}

sub load {
    return new (@_);
}

########################################################################

=head1 INSTANCE METHODS

=head2 reload

=head2 save

=cut

sub reload {
    my $self = shift;
    die "reload: Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };
 
    $self->{path} = rel2abs ($opts->{path}) if ($opts->{path});
    if (-f $self->{path}) {
	$self->{metadata} = Ximian::XML::Simple::XMLin ($self->{path},
						keyattr => [ qw(id) ],
						forcearray => [ qw(i) ],
						contentkey => "cdata");
	$self->{xpath} = XML::XPath->new (filename => $self->{path});
    } else {
	$self->{metadata} = {};
	$self->{xpath} = XML::XPath->new (xml => "");
    }
    # FIXME: this is kind of evil...
    # We don't want the parser to complain about missing dtd's and such.
    $self->{xpath}->{_parser} = XML::Parser->new(ErrorContext => 2);
    return $self;
}

sub save {
    my $self = shift;
    die "reload: Options must be name => value pairs" if (@_ % 2);
    my $opts = { @_ };

    my $path = ($opts->{path} || $self->{path});
    mkdirs get_dirname ($path);
    my $xml = Ximian::XML::Simple::XMLout ($self->{metadata},
				   rootname => "metadata",
				   keyattr => [ qw(id) ],
				   noattr => 1);

    open OUT, ">$path" or die "Could not open: $path";
    print OUT <<END;
<?xml version="1.0" ?>

<!DOCTYPE module SYSTEM "jail-metadata.dtd">

$xml

<!--
Local Variables:
mode: xml
End:
-->
END
    close OUT;
}

########################################################################

=head2 get_path

Return the path to the xml document this metadata object represents.

=head2 get_xml_tree

Return a parsed tree of the xml, as returned by XML::Simple.  Little
processing is done on the tree, only &lt;i&gt; tags are forcearray'd
(see the XML::Simple perldoc for details).

head2 set_xml_tree

Guess.

=head2 get_xpath_obj

Returns an XML::XPath object that can be used to perform queries and
such.  At this time, the xpath object is (a) kept completely separate
from the XML::Simple tree as returned by get_xml_tree, and (b) not the
canonical location for the metadata.  i.e., changes made via the
XML::XPath setNodeText call will not carry over to the xml tree, nor
will they be saved by save().  (In other words, don't use
setNodeText).

=cut

sub get_path {
    my $self = shift;
    return $self->{path};
}

sub get_xml_tree {
    my $self = shift;
    return $self->{metadata};
}

sub set_xml_tree {
    my $self = shift;
    $self->{metadata} = shift;
    return 1;
}

sub get_xpath_obj {
    my $self = shift;
    return $self->{xpath};
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
