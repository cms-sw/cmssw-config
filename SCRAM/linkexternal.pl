#!/usr/bin/env perl
BEGIN{unshift @INC,$ENV{SCRAM_TOOL_HOME};}
use File::Basename;
use Getopt::Long;
use Cache::CacheUtilities;
$|=1;
my $SCRAM_CMD="scramv1";
my %cache=();
$cache{validlinks}{INCLUDE}="include";
$cache{validlinks}{LIBDIR}="lib";

$cache{defaultlinks}{LIBDIR}=1;

$cache{ignorefiles}{LIBDIR}{"python.+"}="d";
$cache{ignorefiles}{LIBDIR}{"modules"}="d";
$cache{ignorefiles}{LIBDIR}{"pkgconfig"}="d";
$cache{ignorefiles}{LIBDIR}{"archive"}="d";

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
if((!defined $arch) || ($arch=~/^\s*$/)){$arch=`$SCRAM_CMD arch`; chomp $arch;}

foreach my $var (@link){if(($var!~/^\s*$/) && (exists $cache{validlinks}{$var})){$cache{defaultlinks}{$var}=1;}}
foreach my $var (@nolink){if(($var!~/^\s*$/) && (exists $cache{defaultlinks}{$var})){delete $cache{defaultlinks}{$var};}}
if(scalar(keys %{$cache{defaultlinks}})==0){exit 0;}

my $curdir   = cwd();
my $localtop = &fixPath(&scramReleaseTop($curdir));
if (!-d "${localtop}/.SCRAM/${arch}"){die "$curdir: Not a SCRAM-Based area. Missing .SCRAM directory.";}
chdir($localtop);
my $cacheext="db";
my $admindir="";
if(&scramVersion($localtop)=~/^V[2-9]/){$cacheext="db.gz";$admindir=$arch;}

if ($all==0)
{
  my $reltop   = `grep RELEASETOP= ${localtop}/.SCRAM/${admindir}/Environment | sed 's|RELEASETOP=||'`; chomp $reltop;
  if($reltop eq ""){$all=1;}
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

if(!-f "${dir}/.SCRAM/${arch}/ToolCache.${cacheext}"){system("scramv1 b -r echo_CXX 2>&1 >/dev/null");}
$cache{toolcache}=&Cache::CacheUtilities::read("${dir}/.SCRAM/${arch}/ToolCache.${cacheext}");

#### Read previous link info
my $externals="external/${arch}";
my $linksDB="${externals}/links.DB";
&readLinkDB ();

if(exists $cache{toolcache}{SETUP})
{
  %tmphash=();
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

##### Ordered list of all tools
&getOrderedTools ();

$cache{DBLINK}={};
foreach my $tooltype ("pretools", "alltools" , "posttools")
{
  if(exists $cache{$tooltype})
  {
    foreach my $t (@{$cache{$tooltype}})
    {
      if(($tooltype eq "alltools") && (exists $cache{posttools_uniq}{$t})){next;}
      if ($t eq "self"){next;}
      if($all || (-f "${dir}/.SCRAM/${admindir}/InstalledTools/$t"))
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
	my $lf="${localtop}/tmp/${arch}/cache/prod/lib${l}";
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
          $dir=&fixPath($dir);
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

sub getOrderedTools ()
{
  my %tmphash=();
  $cache{alltools}=[];
  use BuildSystem::ToolManager;
  my @compilers=();
  foreach my $t (reverse @{$cache{toolcache}->toolsdata()})
  {
    my $tn=$t->toolname();
    if ($t->scram_compiler()) {push @compilers,$tn;next;}
    if(($tn=~/^\s*$/) || (!exists $cache{toolcache}{SETUP}{$tn}) || ($tn eq "self")){next;}
    if(!exists $tmphash{$tn}){$tmphash{$tn}=1;push @{$cache{alltools}},$tn;}
  }
  foreach my $tn (@compilers)
  {
    if(($tn=~/^\s*$/) || (!exists $cache{toolcache}{SETUP}{$tn}) || ($tn eq "self")){next;}
    if(!exists $tmphash{$tn}){$tmphash{$tn}=1;push @{$cache{alltools}},$tn;}
  }
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

#############################################################
sub fixPath ()
{
  my $dir=shift || return "";
  my @parts=();
  my $p="/";
  if($dir!~/^\//){$p="";}
  foreach my $part (split /\//, $dir)
  {
    if($part eq ".."){pop @parts;}
    elsif(($part ne "") && ($part ne ".")){push @parts, $part;}
  }
  return "$p".join("/",@parts);
}

sub scramReleaseTop()
{return &checkWhileSubdirFound(shift,".SCRAM");}

sub checkWhileSubdirFound()
{
  my $dir=shift;
  my $subdir=shift;
  while((!-d "${dir}/${subdir}") && ($dir ne "/")){$dir=dirname($dir);}
  if(-d "${dir}/${subdir}"){return $dir;}
  return "";
}

sub scramVersion ()
{
  my $dir=shift;
  my $ver="";
  if (-f "${dir}/config/scram_version")
  {
    my $ref;
    if(open($ref,"${dir}/config/scram_version"))
    {
      $ver=<$ref>; chomp $ver;
      close($ref);
    }
  }
  return $ver;
}
