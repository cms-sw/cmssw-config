#!/usr/bin/env perl
use File::Basename;
use Getopt::Long;

if(&GetOptions(
               "--project=s",\$project,
               "--version=s",\$version,
               "--scram=s",\$scram,
               "--toolbox=s",\$toolbox,
	       "--config=s",\$config,
	       "--keys=s",\%keys,
               "--help",\$help,
              ) eq ""){print "ERROR: Wrong arguments.\n"; &usage_msg(1);}


if(defined $help){&usage_msg(0);}
if((!defined $project) || ($project=~/^\s*$/)){die "Missing or empty project name.";}
else{$project=uc($project);}
if((!defined $version) || ($version=~/^\s*$/)){die "Missing or empty project version.";}
if((!defined $scram) || ($scram=~/^\s*$/)){die "Missing or empty scram version.";}
if((!defined $toolbox) || ($toolbox=~/^\s*$/)){die "Missing or empty SCRAM tool box path.";}
if(!-d "${toolbox}/configurations"){die "Wrong toolbox directory. Missing directory ${toolbox}/configurations.";}

my $dir="";
if((!defined $config) || ($config=~/^\s*$/))
{
  $dir=dirname($0);
  if($dir!~/^\//){use Cwd;$dir=getcwd()."/${dir}";}
  $dir=&fixPath($dir);
  if($dir=~/^(.+)\/config$/){$config=$1;}
  else{die "Missing config directory path which needs to be updated.";}
}
$dir="${config}/config";

my %cache=();
foreach my $f ("bootsrc","BuildFile","Self","SCRAM_ExtraBuildRule","boot"){$cache{SCRAMFILES}{$f}=1;}
$cache{KEYS}{PROJECT_NAME}=$project;
$cache{KEYS}{PROJECT_VERSION}=$version;
$cache{KEYS}{PROJECT_TOOL_CONF}=$toolbox;
$cache{KEYS}{PROJECT_CONFIG_BASE}=$config;
$cache{KEYS}{SCRAM_VERSION}=$scram;
foreach my $k (keys %keys){$cache{KEYS}{$k}=$keys{$k};}

my $regexp="";
foreach my $k (keys %{$cache{KEYS}})
{
  my $v=$cache{KEYS}{$k};
  $regexp.="s|\@$k\@|$v|g;";
}

opendir(DIR,$dir) || die "Can not open directory for reading: $dir";
foreach my $file (readdir(DIR))
{
  if($file=~/^CVS$/){next;}
  if($file=~/^\./){next;}
  my $fpath="${dir}/${file}";
  if((!-e  $fpath) || (-d $fpath) || (-l $fpath)){next;}
  if($file=~/^${project}_(.+)$/)
  {
    my $type=$1;
    system("mv $fpath ${dir}/${type}; touch ${dir}/XXX_${type}; rm -f ${dir}/*_${type}");
    delete $cache{SCRAMFILES}{$type};
    $cache{FILES}{$type}=1;
  }
  else{$cache{FILES}{$file}=1;}
}
closedir(DIR);
foreach my $type (keys %{$cache{SCRAMFILES}}){system("touch ${dir}/XXX_${type}; rm -f ${dir}/*_${type}*");}

foreach my $file (keys %{$cache{FILES}})
{
  my $fpath="${dir}/${file}";
  if(!-e  $fpath){next;}
  system("sed '".$regexp."' $fpath > ${fpath}.new.$$; mv ${fpath}.new.$$ $fpath");
}
system("rm -rf ${dir}/site; echo $scram > ${dir}/scram_version");

sub fixPath ()
{
  my $dir=shift;
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

sub usage_msg()
{
  my $code=shift || 0;
  print "$0 --project <name> --version <version> --scram <scram version>\n",
        "   --toolbox <toolbox> [--config <dir>] [--help]\n\n",
        "  This script will copy all <name>_<files> files into <files>\n",
        "  and replace project names, version, scram verion, toolbox path",
	"  and extra keys/values provided via the command line. e.g.\n",
	"  $0 -p CMSSW -v CMSSW_4_5_6 -s V1_2_0 -t /path/cmssw-tool-conf/CMS170 --keys MYSTRING1=MYVALUE1 --keys MYSTRING2=MYVALUE2\n",
	"  will release\n",
	"    \@PROJECT_NAME\@=CMSSW\n",
	"    \@PROJECT_VERSION\@=CMSSW_4_5_6\n",
	"    \@SCRAM_VERSION\@=V1_2_0\n",
	"    \@PROJECT_TOOL_CONF\@=/path/cmssw-tool-conf/CMS170\n",
	"    \@MYSTRING1\@=MYVALUE1\n",
	"    \@MYSTRING2\@=MYVALUE2\n\n";
  exit $code;
}
