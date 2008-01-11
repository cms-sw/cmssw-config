#!/usr/bin/env perl
BEGIN{unshift @INC,$ENV{SCRAM_TOOL_HOME};}
use Cache::CacheUtilities;
use UNIVERSAL qw(isa);

my $olddir=shift || die "Missing old installation path";
my $localtop=shift || die "Missing current installation path";
my $arch=shift || die "Missing SCRAM arch";
if($olddir ne $localtop)
{
  my $bdir="${localtop}/.SCRAM/${arch}";
  foreach my $file ("ProjectCache.db","DirCache.db","ToolCache.db")
  {
    my $cache=&Cache::CacheUtilities::read("${bdir}/${file}");
    if(&processbinary($cache)){&Cache::CacheUtilities::write($cache,"${bdir}/${file}");}
  }
  $bdir="${bdir}/MakeData";
  foreach my $file ("DirCache","Tools","src.mk","variables.mk")
  {&processtext("${bdir}/${file}");}
}

sub processtext ()
{
  my $file=shift;
  if(-f $file){&processfile($file);}
  elsif(-d $file){&processdir($file);}
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
    if($line=~s/$olddir/$localtop/g){$flag=1;}
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
  my $dref;
  my $flag=0;
  opendir($dref,$dir) || die "Can not open directory for reading: $dir";
  foreach my $file (readdir($dref))
  {
    if($file=~/^\./){next;}
    if(-d "${dir}/${file}"){next;}
    $flag+=&processfile("${dir}/${file}");
  }
  closedir($dref);
  if($flag>0)
  {
    if(-f "${dir}.mk")
    {
      my @s=stat("${dir}.mk");
      system("cd $dir; find . -name \"*\" -type f | xargs -n 2000 cat >> ${dir}.mk.new");
      system("mv ${dir}.mk.new ${dir}.mk");
      utime $s[9],$s[9],"${dir}.mk";
    }
  }
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
      elsif($v=~s/$olddir/$localtop/g){$changed=1;$cache->{$k}=$v;}
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
      elsif($v=~s/$olddir/$localtop/g){$changed=1;$cache->[$i]=$v;}
    }
  }
  return $changed;
}
