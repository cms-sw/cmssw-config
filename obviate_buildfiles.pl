#! /usr/bin/env perl
# 
# obviate_buildfiles.pl
#     - created by N.Ratnikova, 19 Oct 2006.
#     for building LCGAA with SCRAM V1.
#     Called from config/Project_template.tmpl .
#
#     The purpose of this script is to move out of the way all
#     BuildFiles in LCG projects: SCRAM V0 syntax occasionally
#     breaks proper functioning of the SCRAM V1 build system.
#
#     Script will search for files called BuildFile in a source tree
#     (top directory given as an argument) and rename every such
#     file as .SCRAMV0_BuildFile for backup. Script will not touch
#     the BuildFile if the backup file already exists.
#
####################################################################

use warnings;
use strict;
#set defaults:
my $src=`pwd`; chomp $src;
my $backup_prefix = ".SCRAMV0_";
my $backup_suffix = "";
our $verbose = 0;

sub init{
  use Getopt::Std;
  use Cwd 'abs_path';
  my $opt_string = 'hvd:b:';
  my %opt;
  getopts( "$opt_string", \%opt ) or Usage();
  Usage() if ( $opt{h} or not $opt{d});
  my $dir = $opt{d};
  ( -d $dir) or die "Directory does not exist: $dir \n";
  $backup_suffix = $opt{b} if ($opt{b});
  $verbose = 1 if $opt{v};
  return abs_path($dir);
}

sub wanted {
  #$File::Find::dir is the current directory name,
  #$_ is the current filename within that directory 
  #$File::Find::name is the complete pathname to the file.
  return if ("$_" ne "BuildFile");
  use File::Copy;
  my $bf= $File::Find::name;
  my $backup_file = $backup_prefix . $_ . $backup_suffix;
  return if ( -e $backup_file);
  my $cmd = "mv $_ $backup_file";
  if ($verbose) {
    print "In $File::Find::dir : \n   ";
    print $cmd . "\n";
  }
  qx{$cmd};
}

sub Usage {
  print STDERR << "EOF";
Usage: $0 [-hvd] -d dir
       -h        : this (help) message
       -v        : verbose output
       -d dir    : top source directory of SCRAMV0 managed project
       -b suffix : add suffix to backup file name.

Script will search for files called BuildFile in a source tree
of a given directory and rename every such file as .SCRAMV0_BuildFile
for backup. Script will not touch the BuildFile if the backup file
already exists.
EOF
  exit;
}

$src = init();
if ($verbose) {
  print "Searching to obviate scram V0 build files in:\n     $src\n";
}

use File::Find;
# Note: symbolic links are not followed.
#       Original source code checked out from CVS should not
#       contain any symbolic links.
find (\&wanted, ($src));
