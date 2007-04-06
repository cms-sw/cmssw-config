#!/usr/bin/env perl
use File::Basename;
use Getopt::Long;
$|=1;
my $SCRAM_CMD="scramv1";
my %cache=();
$cache{validlinks}{INCLUDE}="include";
$cache{validlinks}{LIBDIR}="lib";

$cache{defaultlinks}{LIBDIR}=1;

$cache{ignorefiles}{LIBDIR}{"python.+"}="d";
$cache{ignorefiles}{LIBDIR}{"modules"}="d";
$cache{ignorefiles}{LIBDIR}{"pkgconfig"}="d";

if(&GetOptions(
               "--update=s",\@update,
	       "--pre=s",\@pre,
	       "--post=s",\@post,
	       "--nolink=s",\@nolink,
	       "--link=s",\@link,
	       "--arch=s",\$arch,
	       "--all",\$all,
	       "--help",\$help,
              ) eq ""){print "Wrong arguments.\n"; &usage(1);}

if(defined $help){&usage(0);}
if(defined $all){$all=1;} else{$all=0;}

foreach my $var (@link){if(($var!~/^\s*$/) && (exists $cache{validlinks}{$var})){$cache{defaultlinks}{$var}=1;}}
foreach my $var (@nolink){if(($var!~/^\s*$/) && (exists $cache{defaultlinks}{$var})){delete $cache{defaultlinks}{$var};}}
if(scalar(keys %{$cache{defaultlinks}})==0){exit 0;}

my $dir=`/bin/pwd`; chomp $dir;
while ((!-d "${dir}/.SCRAM") && ($dir ne ".") && ($dir ne "/"))
{$dir=dirname($dir);}
if(!-d "${dir}/.SCRAM"){print "ERROR: Please run this script from your SCRAM-based project area.\n"; exit 1;}
my $release=$dir;
chdir($release);

if(-f "${release}/.SCRAM/Environment")
{
  my $rtop=`grep '^RELEASETOP=' ${release}/.SCRAM/Environment | sed 's|RELEASETOP=||'`; chomp $rtop;
  if($rtop eq ""){$all=1;}
}

#### Ordered list of removed tools
my %tmphash=();
$cache{updatetools}=[];
foreach my $t (@update)
{
  my $t=lc($t);
  if(!exists $tmphash{$t}){$tmphash{$t}=1;push @{$cache{updatetools}},$t;}
}

#### Ordered list of tools to be set first
%tmphash=();
$cache{pretools}=[];
foreach my $t (@pre)
{
  my $t=lc($t);
  if(!exists $tmphash{$t}){$tmphash{$t}=1;push @{$cache{pretools}},$t;}
}

#### Ordered list of tools to be set last
$cache{posttools}=[];
$cache{posttools_uniq}={};
foreach my $t (@post)
{
  my $t=lc($t);
  if(!exists $cache{posttools_uniq}{$t}){$cache{posttools_uniq}{$t}=1;push @{$cache{posttools}},$t;}
}

push @{$cache{extradir}}, "";
for(my $i=0;$i<20;$i++)
{
  if($i<10){push @{$cache{extradir}},"0$i";}
  else{push @{$cache{extradir}},"$i";}
}

if((!defined $arch) || ($arch=~/^\s*$/)){$arch=`$SCRAM_CMD arch`; chomp $arch;}
if(!-f "${dir}/.SCRAM/${arch}/ToolCache.db"){system("scramv1 b -r echo_CXX 2>&1 >/dev/null");}
$cache{toolcache}=&readCache($dir);

#### Read previous link info
my $externals="external/${arch}";
my $linksDB="${externals}/links.DB";
&readLinkDB ();

if(exists $cache{toolcache}{SETUP})
{
  my %tmphash=();
  foreach my $t (keys %{$cache{toolcache}{SETUP}})
  {
    if(exists $cache{toolcache}{SETUP}{$t}{LIBDIR})
    {
      if(exists $cache{BASES}{$t})
      {
        foreach my $dir (@{$cache{toolcache}{SETUP}{$t}{LIBDIR}})
        {if(!exists $cache{BASES}{$t}{$dir}){$tmphash{$t}=1;last;}}
      }
      $cache{BASES}{$t}={};
      foreach my $dir (@{$cache{toolcache}{SETUP}{$t}{LIBDIR}})
      {$cache{BASES}{$t}{$dir}=1;}
    }
  }
  if(scalar(keys %tmphash)>0)
  {
    foreach my $t (@{$cache{updatetools}}){$tmphash{$t}=1;}
    $cache{updatetools}=[];
    foreach my $t (keys %tmphash){push @{$cache{updatetools}},$t;}
  }
}

#### Remove all the links for tools passed via command-line arguments
foreach my $t (@{$cache{updatetools}}){&removeLinks($t);}

my @orderedtools=();
foreach my $t (keys %{$cache{toolcache}{SELECTED}})
{
  my $index=$cache{toolcache}{SELECTED}{$t};
  if($index>=0){
    if(!defined $orderedtools[$index]){$orderedtools[$index]=[];}
    push @{$orderedtools[$index]},$t;
  }
}

##### Ordered list of all tools
%tmphash=();
$cache{alltools}=[];
for(my $i=@orderedtools-1;$i>=0;$i--)
{
  if(!defined $orderedtools[$i]){next;}
  foreach my $t (@{$orderedtools[$i]})
  {
    if((!defined $t) || ($t=~/^\s*$/) || (!exists $cache{toolcache}{SETUP}{$t}) || ($t eq "self")){next;}
    if(!exists $tmphash{$t}){$tmphash{$t}=1;push @{$cache{alltools}},$t;}
  }
}

$cache{DBLINK}={};
foreach my $tooltype ("pretools", "alltools" , "posttools")
{
  if(exists $cache{$tooltype})
  {
    foreach my $t (@{$cache{$tooltype}})
    {
      if(($tooltype eq "alltools") && (exists $cache{posttools_uniq}{$t})){next;}
      if ($t eq "self"){next;}
      if($all || (-f "${dir}/.SCRAM/InstalledTools/$t"))
      {if(!exists $cache{donetools}{$t}){$cache{donetools}{$t}=1;&updateLinks($t);}}
    }
  }
}

if(-d $externals)
{
  my $ref;
  open($ref, ">$linksDB") || die "Can not open file \"$linksDB\" for writing.";
  if(exists $cache{DBLINK})
  {foreach my $x1 (sort keys %{$cache{DBLINK}}){foreach my $x2 (sort keys %{$cache{DBLINK}{$x1}}){$x2=~s/^$externals\///;print $ref "L:$x1:$x2\n";}}}
  if(exists $cache{BASES})
  {foreach my $x1 (sort keys %{$cache{BASES}}){foreach my $x2 (sort keys %{$cache{BASES}{$x1}}){print $ref "B:$x1:$x2\n";}}}
  close($ref);

  foreach my $type (sort keys %{$cache{validlinks}})
  {
    $type=$cache{validlinks}{$type};
    foreach my $s (@{$cache{extradir}})
    {
      my $ldir="${externals}/${type}${s}";
      if(-d $ldir){if(!exists $cache{dirused}{$ldir}){system("rm -fr $ldir");}}
      else{last;}
    }
  }
  if(exists $cache{PREDBLINKR})
  {foreach my $lfile (keys %{$cache{PREDBLINKR}}){if(-l $lfile){system("rm -f $lfile");}}}
}
exit 0;

sub readLinkDB ()
{
  if(!exists $cache{PREDBLINK})
  {
    if(-f "$linksDB")
    {
      my $ref;
      open($ref, "${externals}/links.DB") || die "Can not open file \"${externals}/links.db\" for reading.";
      while(my $line=<$ref>)
      {
        chomp $line;
	if($line=~/^L:([^:]+?):(.+)$/){$cache{PREDBLINK}{$1}{"${externals}/${2}"}=1;$cache{PREDBLINKR}{"${externals}/${2}"}{$1}=1;}
	elsif($line=~/^B:([^:]+?):(.+)$/){$cache{BASES}{$1}{$2}=1;}
      }
      close($ref);
    }
    else{$cache{PREDBLINK}={};$cache{PREDBLINKR}={};}
  }
}

sub removeLinks ()
{
  my $tool=shift || return;
  if(exists $cache{PREDBLINK}{$tool})
  {
    foreach my $file (keys %{$cache{PREDBLINK}{$tool}})
    {
      if(-l $file)
      {
	if (scalar(keys %{$cache{PREDBLINKR}{$file}})==1){system("rm -f $file");}
	delete $cache{PREDBLINKR}{$file}{$tool};
      }
    }
    if(exists $cache{toolcache}{SETUP}{$tool}{LIB})
    {
      foreach my $l (@{$cache{toolcache}{SETUP}{$tool}{LIB}})
      {
	my $lf="${release}/tmp/${arch}/cache/prod/lib${l}";
	if(-f "$lf"){if(open(LIBFILE,">$lf")){close(LIBFILE);}}
      }
    }
    delete $cache{PREDBLINK}{$tool};
  }
}

sub updateLinks ()
{
  my $t=shift;
  foreach my $type (sort keys %{$cache{defaultlinks}})
  {
    if(exists $cache{toolcache}{SETUP}{$t}{$type})
    {
      foreach my $dir (@{$cache{toolcache}{SETUP}{$t}{$type}})
      {
        if(-d $dir)
        {
          $dir=&getFixedPath($dir);
	  my $d;
	  opendir($d, $dir) || die "Can not open directory \"$dir\" for reading.";
	  my @files=readdir($d);
	  closedir($d);
	  foreach my $f (@files)
	  {
	    if($f=~/^\.+$/){next;}
	    &createLink ($t, "${dir}/${f}", $type);
	  }
        }
      }
    }
  }
}

sub createLink ()
{
  my $tool=shift || die "Missing tool name";
  my $srcfile=shift || die "Missing source file name";
  my $type=shift || die "Missing type of source file";
  my $file=basename($srcfile);
  if(exists $cache{ignorefiles}{$type})
  {
    foreach my $reg (keys %{$cache{ignorefiles}{$type}})
    {
      my $ftype=$cache{ignorefiles}{$type}{$reg};
      if($file=~/^${reg}$/)
      {
        if((-d $srcfile) && ($ftype=~/^[da]$/i)){return;}
        elsif((-f $srcfile) && ($ftype=~/^[fa]$/i)){return;}
        elsif($ftype=~/^a$/i){return;}
      }
    }
  }
  my $lfile="";
  if(exists $cache{links}{$srcfile})
  {
    $lfile=$cache{links}{$srcfile};
    $cache{DBLINK}{$tool}{$lfile}=1;
    $cache{DBLINKR}{$lfile}=1;
    return;
  }
  $type = $cache{validlinks}{$type};
  my $ldir="";
  foreach my $s (@{$cache{extradir}})
  {
    $ldir="${externals}/${type}${s}";
    $lfile="${ldir}/${file}";
    if(!-d "$ldir"){system("mkdir -p $ldir");}
    if(!-l "$lfile"){system("cd $ldir;ln -s $srcfile .");last;}
    elsif(readlink("$lfile") eq "$srcfile"){last;}
    elsif(!exists $cache{DBLINKR}{$lfile}){system("rm -f $lfile; cd $ldir;ln -s $srcfile .");last;}
  }
  $cache{dirused}{$ldir}=1;
  $cache{links}{$srcfile}=$lfile;
  $cache{DBLINK}{$tool}{$lfile}=1;
  $cache{DBLINKR}{$lfile}=1;
  if(exists $cache{PREDBLINKR}{$lfile}){delete $cache{PREDBLINKR}{$lfile};}
}

sub getFixedPath ()
{
  my $dir=shift;
  my @parts=();
  foreach my $part (split /\//, $dir)
  {
    if($part eq ".."){pop @parts;}
    elsif(($part ne "") && ($part ne ".")){push @parts, $part;}
  }
  return "/".join("/",@parts);
}

sub readCache()
{
  use IO::File;
  my $release=shift  || die "Missing release directory";
  my $cachefilename=shift || "${release}/.SCRAM/${arch}/ToolCache.db";
  my $cachefh = IO::File->new($cachefilename, O_RDONLY)
     || die "Unable to read cached data file $cachefilename: ",$ERRNO,"\n";
  my @cacheitems = <$cachefh>;
  close $cachefh;

  # Copy the new cache object to self and return:
  my $cache = eval "@cacheitems";
  die "Cache load error: ",$EVAL_ERROR,"\n", if ($EVAL_ERROR);
  return $cache;
}

sub usage ()
{
  print "Usage: $0    [--update <tool>  [--update <tool>  [...]]]\n";
  print "             [--pre    <tool>  [--pre    <tool>  [...]]]\n";
  print "             [--post   <tool>  [--post   <tool>  [...]]]\n";
  print "             [--nolink <value> [--nolink <value> [...]]]\n";
  print "             [--link   <value> [--link   <value> [...]]]\n";
  print "             [--all] [--arch <arch>] [--help]\n\n";
  print "--update <tool>  Name of tool(s) for which you want to\n";
  print "                 update the links.\n";
  print "--pre    <tool>  Name of tool(s) for which you want to\n";
  print "                 create links before any other tool.\n";
  print "--post   <tool>  Name of tool(s) for which you want to\n";
  print "                 create links at the end\n";
  print "--nolink <value> Name of the link(s) type which you do\n";
  print "                 not want. Currently available value(s) is(are)\n";
  print "                 \"",join(", ",sort keys %{$cache{validlinks}}),"\" while by default\n";
  print "                 \"",join(", ",sort keys %{$cache{defaultlinks}}),"\" is(are) selected.\n";
  print "--link   <value> Name of the link(s) type which you want to create.\n";
  print "                 Currently available value(s) is(are)\n";
  print "                 \"",join(", ",sort keys %{$cache{validlinks}}),"\" while by default \n";
  print "                 \"",join(", ",sort keys %{$cache{defaultlinks}}),"\" is(are) selected.\n";
  print "--all            By default links for tools setup in\n";
  print "                 your project area will be added. Adding\n";
  print "                 this option will force to create links for\n";
  print "                 all the tools available in your project.\n";
  print "--arch   <arch>  SCRAM_ARCH value. Default is obtained\n";
  print "                 by running \"$SCRAM_CMD arch\" command.\n";
  print "--help           Print this help message.\n";
  exit shift || 0;
}
