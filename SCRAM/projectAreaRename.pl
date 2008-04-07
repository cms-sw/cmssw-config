#!/usr/bin/env perl
BEGIN{unshift @INC,$ENV{SCRAM_TOOL_HOME};}
use Cache::CacheUtilities;
use File::Basename;
use UNIVERSAL qw(isa);

my $olddir=shift || die "Missing old installation path";
my $newtop=shift || die "Missing current installation path";
my $arch=shift || die "Missing SCRAM arch";
my $dir=shift; 
if(!defined $dir){$dir=`/bin/pwd`; chomp $dir;}
my $rel=$dir;
while((!-d "${rel}/.SCRAM") && ($rel!~/^[\.\/]$/)){$rel=dirname($rel);}
if(!-d "${rel}/.SCRAM"){die "$dir is not a SCRAM-based project area.";}

if($olddir ne $newtop)
{
  &processtext("${rel}/.SCRAM",1);
}

sub processtext ()
{
  my $file=shift;
  my $recursive=shift || 0;
  if(-f $file)
  {
    if ($file=~/Cache\.db\.gz$/){return &processcache($file);}
    else{return &processfile($file);}
  }
  elsif(-d $file){return &processdir($file,$recursive);}
  return 0;
}

sub processcache ()
{
  my $file=shift;
  my $cache=&Cache::CacheUtilities::read($file);
  if(&processbinary($cache)){&Cache::CacheUtilities::write($cache,$file);}
}

sub processfile ()
{
  my $file=shift;
  my $inref; my $outref;
  my $flag=0;
  open($inref,"$file") || die "Can not open file for reading:$file\n";
  open($outref,">${file}.new") || die "Can not open file for reading:${file}.new\n";
  while(my $line=<$inref>)
  {
    chomp $line;
    if($line=~s/$olddir/$newtop/g){$flag=1;}
    print $outref "$line\n";
  }
  close($inref);
  close($outref);
  if($flag)
  {
    my @s=stat($file);
    system("mv ${file}.new $file");
    utime $s[9],$s[9],$file;
  }
  else{unlink("${file}.new");}
  return $flag;
}

sub processdir ()
{
  my $dir=shift;
  my $recursive=shift || 0;
  my $dref;
  my $flag=0;
  opendir($dref,$dir) || die "Can not open directory for reading: $dir";
  foreach my $file (readdir($dref))
  {
    if($file=~/^\./){next;}
    if(-d "${dir}/${file}")
    {if($recursive){processdir("${dir}/${file}",$recursive);}}
    else{$flag+=&processext("${dir}/${file}");}
  }
  closedir($dref);
}
  
sub processbinary ()
{
  my $cache=shift;
  my $r=ref($cache);
  my $changed=0;
  if (isa($cache,"HASH"))
  {
    foreach my $k (keys %$cache)
    {
      my $v=$cache->{$k};
      if(isa($v,"HASH")){$changed+=&processbinary(\%$v);}
      elsif(isa($v,"ARRAY")){$changed+=&processbinary(\@$v);}
      elsif($v=~s/$olddir/$newtop/g){$changed=1;$cache->{$k}=$v;}
    }
  }
  elsif(isa($cache,"ARRAY"))
  {
    my $c=scalar(@$cache);
    for(my $i=0;$i<$c;$i++)
    {
      my $v=$cache->[$i];
      if(isa($v,"HASH")){$changed+=&processbinary(\%$v);}
      elsif(isa($v,"ARRAY")){$changed+=&processbinary(\@$v);}
      elsif($v=~s/$olddir/$newtop/g){$changed=1;$cache->[$i]=$v;}
    }
  }
  return $changed;
}
