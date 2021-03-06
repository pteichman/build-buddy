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

package RcdOperations;

use Ximian::RCD;
use Ximian::Run ':all';
use Ximian::Util ':all';
use Ximian::BB::Globals;
use Ximian::BB::Module ':all';
use Ximian::BB::Macros ':all';

Ximian::BB::Plugin::register
    (name => "rcd",
     group => "operations",
     operations =>
     [
      { name => "rcd:setup",
        description => "Sets up RCD daemon.",
        pre => \&setup },

      { name => "rcd:cleanup",
        description => "Stops the RCD daemon.",
        pre => \&set_rcd,
        post => \&cleanup },

      { name => "rcd:print-info",
        description => "Prints information about the current RCD configuration.",
        pre => \&info },

      { name => "rcd:project-deps",
        description => "Installs the build dependencies for the project.",
        pre => \&install_deps },

      { name => "rcd:module-deps",
        description => "Installs the build dependencies for a module.",
        pre => \&set_rcd,
        module => \&install_module_deps },

      { name => "rcd:install",
        description => "Installs packages generated by module.",
        pre => \&set_rcd,
        module => \&install,
        deps => ['build'] },

      { name => "rcd:uninstall",
        description => "Removes module's installed packages.",
        pre => \&set_rcd,
        module => \&uninstall },
      ]);

########################################################################

my $rcd;

sub set_rcd {
    $rcd = Ximian::RCD->instance unless $rcd;
    return 0;
}

sub setup {
    my ($pconf, $data) = @_;
    return 0 unless keys %{$pconf->{rcd}};
    my $c = $pconf->{rcd};

    my $system = 1;
    $system = 0 if $c->{use_system} eq "0" or $c->{use_system} eq "no";
    $rcd = Ximian::RCD->instance (use_system => $system);

    if ($c->{var}) {
        $rcd->set_var (%{$c->{var}}) or return 1;
    }

    while (my ($sid, $svc) = each %{$c->{service}}) {
        $rcd->add_service ($svc->{url}) if $svc->{url};
        foreach my $key (@{$svc->{activation}->{i}}) {
            $rcd->activate_key (($svc->{url} || $sid), $key) or return 1;
        }
    }
    $rcd->refresh or return 1;

    if ($c->{subscribe} and @{$c->{subscribe}->{i}}) {
        $rcd->subscribe (macro_replace \@{$c->{subscribe}->{i}})
            or return 1;
    }
    if ($c->{update} and @{$c->{update}->{i}}) {
        $rcd->update_channel (macro_replace \@{$c->{update}->{i}})
            or return 1;
    }
    return 0;
}

sub cleanup {
    my ($success, $pconf, $data) = @_;
    return $rcd->stop;
}

sub info {
    my ($pconf, $data) = @_;
    set_rcd;
    $rcd->print_preferences;
    $rcd->print_services;
    $rcd->print_channels;
    $rcd->print_packages if $Ximian::Globals::verbosity >= 5; # slow!
}

sub install_deps {
    my ($pconf, $data) = @_;
    set_rcd;
    if (exists $pconf->{builddep} and %{$pconf->{builddep}}) {
        $rcd->solvedeps (macro_replace ($pconf->{builddep}->{i}));
    }
    return 0;
}

sub install_module_deps {
    my ($module, $data) = @_;
    my $conf = $module->{conf};
    if (exists $conf->{builddep} and %{$conf->{builddep}}) {
	my @deps;
        foreach my $i (qw/buildprereqs buildrequires/) {
            push @deps, @{$conf->{builddep}->{$i}->{i}} if exists $conf->{builddep}->{$i};
        }
        $rcd->solvedeps (macro_replace (\@deps));
    }
    return 0;
}

sub install {
    my ($module, $data) = @_;
    my @files = map { "$data->{archivedir}/$_" } module_files ($module->{conf});
    return $rcd->install (@files);
}

sub uninstall {
    my ($module, $data) = @_;
    return $rcd->install (package_names ($module->{conf}));
}

1;
