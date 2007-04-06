#!/usr/bin/env perl
my $olddir=shift || die "Missing old installation path";
my $localtop=shift || die "Missing current installation path";
my $arch=shift || die "Missing SCRAM arch";
if($olddir ne $localtop)
{
  my $done=0;
  foreach my $file ("${localtop}/.SCRAM/${arch}/ToolCache.db", "${localtop}/.SCRAM/${arch}/ProjectCache.db", "${localtop}/.SCRAM/DirCache.db")
  {$done+=&processfile($file);}
  if($done>0){system("scramv1 build -r echo_CXX >/dev/null 2>&1");}
}
  
sub processfile ()
{
  my $changed=0;
  my $file=shift || return $changed;
  if(!-f $file){return $changed;}
  open(INFILE,$file) || die "Can not open \"$file\" for reading.";
  if(!open(OUTFILE,">${file}.new")){close(INFILE); die "Can not open \"${file}.new\" for writing.";}
  my $line;
  while($line=<INFILE>)
  {
    chomp $line;
    while($line=~/^(.*?)($olddir)(['\/].*)$/)
    {$line="${1}${localtop}${3}";$changed=1;}
    print OUTFILE "$line\n";
  }
  close(INFILE);
  close(OUTFILE);
  system("mv ${file}.new $file");
  return $changed;
}
