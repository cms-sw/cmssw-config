package SCRAM::Plugins::CustomPlugin;
use vars qw( @ISA );
use base qw(Template::Plugin);
use Template::Plugin;
use Exporter;
use File::Basename;
use Cache::CacheUtilities;
@ISA=qw(Exporter);

sub load()
{
  my ($class, $context) = @_;
  my $self = {};
  $self->{context}=undef;
  bless($self, $class);
  $self->loadInit_();
  return $self;   
}

sub loadInit_ ()
{
  my $self=shift;
  foreach my $var ("SCRAM_PROJECTNAME", "LOCALTOP", "SCRAM_ARCH", "SCRAM_INTwork", "SCRAM_CONFIGDIR", "THISDIR")
  {
    my $val="";
    if(exists $ENV{$var}){$val=$ENV{$var};}
    if($val=~/^\s*$/){die "Environment variable \"$var\" does not exist.";}
  }
  foreach my $ext ("f","f77","F","F77")
  {$self->{cache}{SourceExtensions}{fortran}{$ext}=1;}
  foreach my $ext ("cc","cpp","cxx","C")
  {$self->{cache}{SourceExtensions}{cxx}{$ext}=1;}
  foreach my $ext ("c")
  {$self->{cache}{SourceExtensions}{c}{$ext}=1;}
  $ENV{LOCALTOP}=&fixPath($ENV{LOCALTOP});
}

sub new()
{
  my $self=shift;
  $self->{context}=shift;
  $self->{core}=shift;
  $self->newInit_();
  return $self;
}

sub newInit_ ()
{
  my $self=shift;
  my $context=$self->{context};
  if(!$context->isa("Template::Context"))
  {
    my $ref=ref($context);
    die "Can not initialize CustomPlugin. \"$ref\" pased instead of \"Template::Context\".";
  }
  my $class = $self->{context}->stash()->get('class');
  &runFunction("initTemplate_${class}",$self);
}

sub getTool ()
{
  my $self=shift;
  my $tool=shift;
  if((exists $self->{cache}{toolcache}) && (exists $self->{cache}{toolcache}{SETUP}{$tool}))
  {return $self->{cache}{toolcache}{SETUP}{$tool};}
  return {};
}

sub isDependentOnTool ()
{
  my $self=shift;
  my $tool=shift;
  my $bdata=$self->{core}->data("USE");
  if((defined $bdata) && (ref($bdata) eq "ARRAY"))
  {
    foreach my $t (@$bdata)
    {
      my $tx=lc($t);
      foreach my $t1 (@$tool){if($tx eq $t1){return 1;}}
    }
  }
  return 0;
}

sub isToolAvailable ()
{
  my $self=shift;
  my $tool=lc(shift) || return 0;
  if((exists $self->{cache}{toolcache}) && (exists $self->{cache}{toolcache}{SETUP}{$tool})){return 1;}
  return 0;
}

sub toolDeps ()
{
  my $self=shift;
  my @tools=();
  my $bdata=$self->{context}->stash()->get('branch')->branchdata();
  if((defined $bdata) && (ref($bdata) eq "BuildSystem::DataCollector"))
  {foreach my $t (@{$bdata->{BUILD_ORDER}}){push @tools,$t;}}
  return @tools;
}

sub getEnv ()
{
  my $self=shift;
  my $var=shift;
  if(exists $ENV{$var}){return $ENV{$var};}
  return "";
}

sub processTemplate ()
{
  return &projectSpecificTemplate(shift,"process",@_);
}

sub includeTemplate ()
{
  return &projectSpecificTemplate(shift,"include",@_);
}

sub projectSpecificTemplate ()
{
  my $self=shift;
  my $type=shift;
  my $name=shift || return;
  my $context=$self->{context};
  my $tmplfile=$self->{cache}{ProjectName}."_${name}.tmpl";
  my $tmplfpath=$self->{cache}{ProjectConfig}."/$tmplfile";
  if(-f $tmplfpath)
  {
    if($type eq "process"){return $context->process($tmplfile,@_);}
    else{return $context->include($tmplfile,@_);}
  }
  return;
}

sub unsupportedProductType ()
{
  my $self=shift;
  my $stash=$self->{context}->stash();
  my $path = $stash->get("path");
  my $type = $stash->get("type");
  print STDERR "WARNING: Product type \"$type\" not supported yet from \"$path\".\n";
  if($path=~/\/src$/)
  {print STDERR "WARNING: You are only suppose to build a single library from \"$path\".\n";}
  return;
}

sub getSubDirIfEnabled ()
{
  my $self=shift;
  my $flag=$self->{core}->flags("ADD_SUBDIR");
  if(($flag=~/^yes$/i) || ($flag == 1))
  {
    my $path=$self->{context}->stash()->get('path');
    my $subdir=[];
    $subdir=&readDir($path,1,-1);
    return join(" ",sort(@$subdir));
  }
  return;
}
##############################################################
sub fixData ()
{
  my $self=shift;
  my $data=shift;
  my $type=shift;
  my $bf=shift;
  my $section=shift;
  my $ndata=[];
  if (ref($data) ne "ARRAY") {return "";}
  if (scalar(@$data)==0){return "";}
  if(defined $section){$section="export";}
  else{$section="non-export";}
  my $ltop=$self->{cache}{LocalTop};
  my $rtop="";
  my $udata={};
  if($self->{cache}{ReleaseArea} == 0)
  {$rtop=$ENV{RELEASETOP};}
  if ($type eq "INCLUDE")
  {
    my $ldir=dirname($bf);
    foreach my $d (@$data)
    {
      my $x=$d;
      $x=~s/^\s*//;$x=~s/\s*$//;
      if($x=~/^[^\/\$]/){$x="${ltop}/${ldir}/${x}";}
      $x=&fixPath($x);
      if(!exists $udata->{$x}){$udata->{$x}=1;push @$ndata,$x;}
      else{print STDERR "***WARNING: Multiple usage of \"$d\". Please cleanup \"$type\" in \"$section\" section of \"$bf\".\n";}
    }
  }
  elsif($type eq "USE")
  {
    foreach my $u (@$data)
    {
      my $x=$u;
      $x=~s/^\s*//;$x=~s/\s*$//;
      my $lx=lc($x);
      if($lx eq $self->{cache}{CXXCompiler}){next;}
      my $found=0;
      foreach my $dir ($ltop,$rtop)
      {if(($dir ne "") && (-f "${dir}/.SCRAM/$ENV{SCRAM_ARCH}/timestamps/${lx}")){$found=1;last;}}
      if(!$found){$lx=$x;}
      if(!exists $udata->{$lx}){$udata->{$lx}=1;push @$ndata,$lx;}
      else{print STDERR "***WARNING: Multiple usage of \"$lx\". Please cleanup \"$type\" in \"$section\" section of \"$bf\".\n";}
    }
  }
  elsif($type eq "LIB")
  {
    foreach my $l (@$data)
    {
      my $x=$l;
      $x=~s/^\s*//;$x=~s/\s*$//;
      if($x eq "1"){$x=$self->{context}->stash()->get('safename');}
      if(!exists $udata->{$x}){$udata->{$x}=1;push @$ndata,$x;}
      else{print STDERR "***WARNING: Multiple usage of \"$l\". Please cleanup \"$type\" in \"$section\" section of \"$bf\".\n";}
    }
  }
  if(scalar(@$ndata)==0){return "";}
  return $ndata;
}

##############################################################
sub allProductDirs ()
{
  my $self=shift;
  return keys %{$self->{cache}{ProductTypes}};
}

sub addProductDirMap ()
{
  my $self=shift;
  my $type=lc(shift) || return;
  my $reg=shift || return;
  my $dir=shift || return;
  my $index=shift;
  if(!defined $index){$index=100;}
  $self->{cache}{ProductTypes}{$type}{DirMap}{$index}{$reg}=$dir;
  return;
}

sub resetProductDirMap ()
{
  my $self=shift;
  my $type=lc(shift) || return;
  delete $self->{cache}{ProductTypes}{$type}{DirMap};
  return;
}

sub getProductStore ()
{
  my $self=shift;
  my $stash=$self->{context}->stash();
  my $type = shift || $stash->get('type');
  my $path = shift || $stash->get('path');
  if(exists $self->{cache}{ProductTypes}{$type}{DirMap})
  {
    foreach my $ind (sort {$a <=> $b} keys %{$self->{cache}{ProductTypes}{$type}{DirMap}})
    {
      foreach my $reg (keys %{$self->{cache}{ProductTypes}{$type}{DirMap}{$ind}})
      {if($path=~/$reg/){return $self->{cache}{ProductTypes}{$type}{DirMap}{$ind}{$reg};}}
    }
  }
  else{print STDERR "****ERROR: Product store \"$type\" not available. Please fix the build template loaded for \"$path\".\n";}
  return "";
}

sub setIgletFile ()
{
  my $self=shift;
  my $file=shift || return;
  $self->{cache}{IgLetFile}=$file;
  return;
}

sub getIgletFile ()
{
  my $self=shift;
  my $file="";
  if(exists $self->{cache}{IgLetFile}){$file=$self->{cache}{IgLetFile};}
  return $file;
}
##############################################################
sub setLCGCapabilitiesPluginType ()
{
  my $self=shift;
  my $type=lc(shift) || $self->{cache}{DefaultPluginType};
  if(!exists $self->{cache}{SupportedPlugins}{$type})
  {
    print STDERR "****ERROR: LCG Capabilities Plugin type \"$type\" not supported.\n";
    print STDERR "           Currently available plugins are:",join(",",sort keys %{$self->{cache}{SupportedPlugins}}),".\n";
  }
  else{$self->{cache}{LCGCapabilitiesPlugin}=$type;}
  return;
}

sub getLCGCapabilitiesPluginType ()
{
  my $self=shift;
  my $type=$self->{cache}{LCGCapabilitiesPlugin} || $self->{cache}{DefaultPluginType};
  return $type;
}

sub addPluginSupport ()
{
  my $self=shift;
  my $type=lc(shift) || return;
  my $flag=uc(shift) || return;
  my $refresh=shift  || return;
  my $reg=shift      || "";
  my $dir=shift      || "SCRAMSTORENAME_MODULE";
  my $cache=shift    || ".cache";
  my $name=shift     || '$name="${name}.reg"';
  my $ncopylib=shift || "";
  my $err=0;
  foreach my $t (keys %{$self->{cache}{SupportedPlugins}})
  {
    if($t eq $type){next;}
    my $c=$self->{cache}{SupportedPlugins}{$t}{Cache};
    my $r=$self->{cache}{SupportedPlugins}{$t}{Refresh};
    if($r eq $refresh){print STDERR "****ERROR: Can not have two plugins type (\"$t\" and \"$type\") using the same plugin refresh command \"$r\"\n.";$err=1;}
    if("$c" eq "$cache"){print STDERR "****ERROR: Can not have two plugins type (\"$t\" and \"$type\") using the same plugin cache file \"$c\"\n.";$err=1;}
  }
  if(!$err)
  {
    $self->{cache}{SupportedPlugins}{$type}{Refresh}=$refresh;
    $self->{cache}{SupportedPlugins}{$type}{Flag}=[];
    foreach my $f (split /:/,$flag){push @{$self->{cache}{SupportedPlugins}{$type}{Flag}}, $f;}
    $self->{cache}{SupportedPlugins}{$type}{Cache}=$cache;
    $self->{cache}{SupportedPlugins}{$type}{DefaultDirName}=$reg;
    $self->{cache}{SupportedPlugins}{$type}{Dir}=$dir;
    $self->{cache}{SupportedPlugins}{$type}{Name}=$name;
    $self->{cache}{SupportedPlugins}{$type}{NoSharedLibCopy}=$ncopylib;
    $self->{cache}{SupportedPlugins}{$type}{DirMap}={};
  }
  return;
}

sub addPluginDirMap ()
{
  my $self=shift;
  my $type=lc(shift) || return;
  my $reg=shift || return;
  my $dir=shift || return;
  my $index=shift;
  if(!defined $index){$index=100;}
  if(!exists $self->{cache}{SupportedPlugins}{$type})
  {print STDERR "****ERROR: Not a valid plugin type \"$type\". Available plugin types are:",join(", ", keys %{$self->{cache}{SupportedPlugins}}),"\n";}
  $self->{cache}{SupportedPlugins}{$type}{DirMap}{$index}{$reg}=$dir;
  return;
}

sub removePluginSupport ()
{
  my $self=shift;
  my $type=lc(shift) || return;
  delete $self->{cache}{SupportedPlugins}{$type};
  return;
}

sub getPluginProductDirs ()
{
  my $self=shift;
  my %dirs=();
  my $type=lc(shift) || return keys(%dirs);
  if(exists $self->{cache}{SupportedPlugins}{$type})
  {
    $dirs{$self->{cache}{SupportedPlugins}{$type}{Dir}}=1;
    foreach my $ind (keys %{$self->{cache}{SupportedPlugins}{$type}{DirMap}})
    {foreach my $x (keys %{$self->{cache}{SupportedPlugins}{$type}{DirMap}{$ind}}){$dirs{$self->{cache}{SupportedPlugins}{$type}{DirMap}{$ind}{$x}}=1;}}
  }
  return keys(%dirs);
}

sub getPluginData ()
{
  my $self=shift;
  my $key=shift || return "";
  my $type=lc(shift) || $self->getDefaultPluginType ();
  my $val="";
  if(exists $self->{cache}{SupportedPlugins}{$type} && exists $self->{cache}{SupportedPlugins}{$type}{$key}){$val=$self->{cache}{SupportedPlugins}{$type}{$key};}
  return $val;
}

sub getPluginTypes ()
{
  my $self=shift;
  return keys %{$self->{cache}{SupportedPlugins}};
}

sub setProjectDefaultPluginType ()
{
  my $self=shift;
  my $type=lc(shift) || $self->{cache}{DefaultPluginType};
  if(!exists $self->{cache}{SupportedPlugins}{$type})
  {
    print STDERR "****ERROR: Invalid plugin type \"$type\". Currently supported plugins are:",join(",",sort keys %{$self->{cache}{SupportedPlugins}}),".\n";
    return;
  }
  $self->{cache}{DefaultPluginType}=$type;
  return;
}

sub setDefaultPluginType ()
{
  my $self=shift;
  my $type=lc(shift) || $self->{cache}{DefaultPluginType};
  if(!exists $self->{cache}{SupportedPlugins}{$type})
  {
    my $core=$self->{core};
    my @bf=keys %{$core->bfdeps()};
    print STDERR "****ERROR: Invalid plugin type \"$type\". Currently supported plugins are:",join(",",sort keys %{$self->{cache}{SupportedPlugins}}),".\n";
    print STDERR "           Please fix the \"$bf[@bf-1]\" file first. For now no plugin will be generated for this product.\n";
    $type="";
  }
  $self->{context}->stash()->set('plugin_type',$type);
  return;
}

sub getDefaultPluginType ()
{
  my $self=shift;
  my $type="";
  if(exists $self->{cache}{DefaultPluginType}){$type=$self->{cache}{DefaultPluginType};}
  return $type;
}

sub checkSealPluginFlag ()
{
  my $self=shift;
  my $stash=$self->{context}->stash();
  my $core=$self->{core};
  my $path = $stash->get('path');
  my $libname=$stash->get('safename');
  my @bf=keys %{$core->bfdeps()};
  my $flags=$core->allflags();
  my $err=0;
  my $plugintype=$stash->get('plugin_type');
  my $plugin=0;
  if ($plugintype ne "")
  {
    $plugin=1;
    $plugintype=lc($plugintype);
    if(!exists $self->{cache}{SupportedPlugins}{$plugintype})
    {
      $err=1;
      print STDERR "****ERROR: Plugin type \"$plugintype\" not supported. Currently available plugins are:",join(",",sort keys %{$self->{cache}{SupportedPlugins}}),".\n";
      $plugintype="";
    }
  }
  else
  {
    my %xflags=();
    foreach my $ptype (keys %{$self->{cache}{SupportedPlugins}})
    {
      foreach my $pflag (@{$self->{cache}{SupportedPlugins}{$ptype}{Flag}})
      {
        if(exists $flags->{$pflag})
        {
          $xflags{$pflag}=1;
	  $plugin=$flags->{$pflag}[0];
	  $plugintype=$ptype;
	  if($pflag eq "SEAL_PLUGIN_NAME"){$plugin=1;}
	  if($plugin!~/^[01]$/)
	  {
            print STDERR "****ERROR: Only allowed values for \"$pflag\" flag are \"0\" OR \"1\". Please fix this for \"$libname\" library in \"$bf[@bf-1]\" file.\n";
            $err=1;
	  }
	}
      }
    }
    if(scalar(keys %xflags)>1)
    {
      print STDERR "****ERROR: More than one plugin flags\n";
      foreach my $f (keys %xflags){print STDERR "             $f\n";}
      print STDERR "           are set for \"$libname\" library in \"$bf[@bf-1]\" file.\n";
      print STDERR "           You only need to provide one flag. Please fix this first otherwise plugin will not be registered.\n";
      $err=1;
    }
    if($plugintype eq "")
    {
      foreach my $t (keys %{$self->{cache}{SupportedPlugins}})
      {
        my $exp=$self->{cache}{SupportedPlugins}{$t}{DefaultDirName};
        if($path=~/$exp/)
        {
          if(exists $flags->{DEFAULT_PLUGIN})
          {
  	    $self->setDefaultPluginType($flags->{DEFAULT_PLUGIN});
	    $plugintype=$stash->get('plugin_type');
	    if($plugintype eq ""){$err=1;}
	  }
	  else{$plugintype=$t;}
	  $plugin=1;
	  last;
        }
      }
    }
    if ($plugintype eq "")
    {
      if(exists $flags->{DEFAULT_PLUGIN})
      {
        $self->setDefaultPluginType($flags->{DEFAULT_PLUGIN});
	$plugintype=$stash->get('plugin_type');
	if($plugintype eq ""){$err=1;}
      }
    }
  }
  my $pnf = $stash->get('plugin_name_force');
  my $pn = $stash->get('plugin_name');
  if(($plugintype eq "") && ($pn ne "")){$plugintype=$self->{cache}{DefaultPluginType};$plugin=1;}
  
  if($plugin == 1){if($pn eq ""){$pn=$libname;}}
  if(($pn ne "") && ($pnf eq "") && ($libname ne $pn))
  {
    print STDERR "****ERROR: Plugin name should be same as the library name. Please fix the \"$bf[@bf-1]\" file and replace \"$pn\" with \"$libname\"\n";
    print STDERR "           Please fix the above error otherwise library \"$libname\" will not be registered as plugin.\n";
    $err=1;
  }
  if($err)
  {
    if(!$self->isReleaseArea()){exit 1;}
    else{$stash->set('plugin_name', $pn);return;}
  }
  
  $stash->set('plugin_name', $pn);
  if($pn ne "")
  {
    my $pd = $self->{cache}{SupportedPlugins}{$plugintype}{Dir};
    my $f=0;
    foreach my $ind (sort {$a <=> $b} keys %{$self->{cache}{SupportedPlugins}{$plugintype}{DirMap}})
    {
      foreach my $reg (keys %{$self->{cache}{SupportedPlugins}{$plugintype}{DirMap}{$ind}})
      {if($path=~/$reg/){$pd=$self->{cache}{SupportedPlugins}{$plugintype}{DirMap}{$ind}{$reg}; $f=1;last;}}
      if($f){last;}
    }
    $stash->set('plugin_type', $plugintype);
    $stash->set('plugin_dir',$pd);
    my $nexp=$self->{cache}{SupportedPlugins}{$plugintype}{Name};
    my $name=$pn;
    if($plugintype eq "iglet"){$name=~s/_ExtraIglet$//;}
    eval $nexp;
    $stash->set('plugin_product', $name);
    $stash->set("no_shared_lib_copy",$self->{cache}{SupportedPlugins}{$plugintype}{NoSharedLibCopy});
  }
  return;
}
######################################################
sub addAllVariables ()
{
  my $self=shift;
  my @keys=();
  if((exists $self->{cache}{toolcache}) && (exists $self->{cache}{toolcache}{SETUP}))
  {
    foreach my $t (keys %{$self->{cache}{toolcache}{SETUP}})
    {
      if(exists $self->{cache}{toolcache}{SETUP}{$t}{VARIABLES})
      {
        foreach my $v (@{$self->{cache}{toolcache}{SETUP}{$t}{VARIABLES}})
	{
	  if(exists $self->{cache}{toolcache}{SETUP}{$t}{$v})
	  {
	    if($self->shouldAddToolVariables($v)){push @keys, "$v:=".$self->{cache}{toolcache}{SETUP}{$t}{$v};}
	  }
	}
      }
    }
  }
  return @keys;
}

sub shouldAddToolVariables()
{
  my $self=shift;
  my $var=shift;
  if(exists $self->{cache}{ToolVariables}{$var}){return 0;}
  $self->{cache}{ToolVariables}{$var}=1;
  return 1;
}

sub shouldAddMakeData ()
{
  my $self=shift;
  my $stash=$self->{context}->stash();
  if(exists $stash->{nomake_data}){return 0;}
  return 1;
}

sub shouldRunMoc ()
{
  my $self=shift;
  my $hasmoc=0;
  if($self->isDependentOnTool(["qt","soqt"]))
  {
    my $stash=$self->{context}->stash();
    my $src=$stash->get('path');
    my $inc=$src;
    $inc=~s/\/src$/\/interface/;
    $stash->set(mocsrc => "$src");
    $stash->set(mocinc => "$inc");
    my $mocfiles="";
    foreach my $dir ($src, $inc)
    {
      my $dref;
      if(opendir($dref, $dir))
      {
         foreach my $file (readdir($dref))
	 {
	   if($file=~/^\./){next;}
	   if(-d "${dir}/${file}"){next;}
	   if($file=~/.+?\.(h|cc|cpp|cxx|C)$/)
	   {
	     my $fref;
	     if (open($fref,"${dir}/${file}"))
	     {
	       my $line;
	       while($line=<$fref>)
	       {
	         chomp $line;
	         if($line=~/Q_OBJECT/){$mocfiles.=" ${file}";$hasmoc=1;last;}
	       }
	       close($fref);
	     }
	   }
	 }
	 closedir($dref);
      }
    }
    $stash->set(mocfiles => "$mocfiles");
  }
  return $hasmoc;
}

sub isLibSymLoadChecking ()
{
  my $self=shift;
  my $flag=$self->{core}->flags("NO_LIB_CHECKING");
  if(($flag!~/^yes$/i) && ($flag ne "1")){$flag="";}
  else{$flag="no";}
  return $flag;
}

sub getLocalBuildFile ()
{
  my $self=shift;
  my $path=$self->{context}->stash()->get('path');
  my $bn=$self->{cache}{BuildFile};
  my $bf="${path}/${bn}.xml";
  if(!-f $bf)
  {
    $bf="${path}/${bn}";
    if (!-f $bf)
    {
      my $pub = $self->{core}->publictype();
      if ($pub)
      {
        $path=dirname($path);
        $bf="${path}/${bn}.xml";
	if (!-f $bf){$bf="${path}/${bn}";}
      }
    }
  }
  if(!-f $bf){$bf="";}
  else{$bf=~s/\.xml//;}
  return $bf;
}

sub setBuildFileName ()
{
  my $self=shift;
  my $file=shift || return;
  $self->{cache}{BuildFile}=$file;
  return ;
}

sub getBuildFileName ()
{
  my $self=shift;
  return $self->{cache}{BuildFile};
}

sub setCompiler ()
{
  my $self=shift;
  my $type=uc(shift);
  my $compiler=lc(shift);
  $self->{cache}{"${type}Compiler"}=$compiler;
  return ;
}

sub getCompiler ()
{
  my $self=shift;
  my $type=uc(shift);
  if (exists $self->{cache}{"${type}Compiler"}){return  $self->{cache}{"${type}Compiler"};}
  return "";
}

sub shouldAddCompilerFlag ()
{
  my $self=shift;
  my $flag=shift;
  if(exists $self->{cache}{CompilerFlags}{$flag}){return 0;}
  $self->{cache}{CompilerFlags}{$flag}=1;
  return 1;
}

sub isReleaseArea ()
{
  my $self=shift;
  return $self->{cache}{ReleaseArea};
}

sub hasPythonscripts ()
{
  my $self=shift;
  my $stash=$self->{context}->stash();
  my $path=&fixPath($stash->get('path'));
  my $pythonprod={};
  my $flags=$self->{core}->allflags();
  if(exists $flags->{PYTHONPRODUCT})
  {
    my $flags1=$flags->{PYTHONPRODUCT};
    my $bfile=$self->getLocalBuildFile();
    my $xfiles=[];
    my $xdirs=[];
    foreach my $p (@$flags1)
    {
      my @files=split /,/,$p;
      my $count=scalar(@files);
      if($count==1){push @files,"";$count++;}
      if($count==0){print STDERR "ERROR: Invalid use of \"PYTHONPRODUCT\" flag in \"$bfile\" file. Please correct it.\n";}
      else
      {
        my $des=$self->{cache}{PythonProductStore}."/".$files[$count-1];
	$des=~s/\/+$//;
	pop @files;
	my $list="";
	foreach my $fs (@files)
	{
	  foreach my $f (split /\s+/,$fs)
	  {
	    $f=&fixPath("${path}/${f}");
	    if(!-f $f){print STDERR "ERROR: No such file \"$f\" for \"PYTHONPRODUCT\" flag in \"$bfile\" file. Please correct it.\n";}
	    else{$pythonprod->{$f}=1;push @$xfiles,$f;push @$xdirs,$des;}
	  }
	}
      }
    }
    $stash->set("xpythonfiles",$xfiles);
    $stash->set("xpythondirs",$xdirs);
  }
  my $scripts = 0;
  if($self->{cache}{SymLinkPython} == 0)
  {
    foreach my $f (@{&readDir($path,2,-1)})
    {
      if(exists $pythonprod->{$f}){next;}
      if($f=~/\.py$/)
      {$scripts = 1;last;}
    }
  }
  else{$scripts=1;}
  $stash->set(hasscripts => $scripts);
  return $scripts;
}

sub symlinkPythonDirectory ()
{
  my $self=shift;
  $self->{cache}{SymLinkPython}=shift;
  return;
}

sub isSymlinkPythonDirectory ()
{
  my $self=shift;
  return $self->{cache}{SymLinkPython};
}

sub isRuleCheckerEnabled ()
{
  my $self=shift;
  my $res=0;
  if ((exists $ENV{CMS_RULECHECKER_ENABLED}) && ($ENV{CMS_RULECHECKER_ENABLED}=~/^(yes|1)$/i))
  {
    my $path=$self->{context}->stash()->get('path');
    if($path=~/\/src$/){$res=1;}
  }
  return $res;
}

sub isCodeGen ()
{
  my $self=shift;
  my $res=0;
  my $path=$self->{context}->stash()->get('path');
  foreach my $f (@{&readDir($path,2,1)})
  {if($f=~/\/.+?\.desc\.xml$/){$res=1;last;}}
  return $res;
}

sub setLibPath ()
{
  my $self=shift;
  my $stash=$self->{context}->stash();
  my $path = $stash->get('path');
  if($path=~/src\/.+\/src$/){$stash->set('libpath', 1);}
  else{$stash->set('libpath', 0);}
  return;
}
sub searchLexYacc ()
{
  my $self=shift;
  my $stash=$self->{context}->stash();
  my $lex="";
  my $parse="";
  my $path = $stash->get('path');
  foreach my $f (@{&readDir($path,2,1)})
  {
    if($f=~/\/.+?lex\.l$/){$lex.=" $f";}
    elsif($f=~/\/.+?parse\.y$/){$parse.=" $f";}
  }
  $stash->set(lexyacc => $lex);
  $stash->set(parseyacc => $parse);
  if($lex || $parse){return 1;}
  return 0;
}

sub searchLCGRootDict ()
{
  my $self=shift;
  my $stash=$self->{context}->stash();
  my $core=$self->{core};
  my $stubdir="";
  my $lcgheader=[];
  my $lcgxml=[];
  my $headers=[];
  my $rootmap=0;
  my $genreflex_args="--deep";
  my $rootdict="";
  my $path=$stash->get('path');
  my $dir=$path;
  my $top=$ENV{LOCALTOP};
  my @files=split /\s+/,$core->productfiles();
  my $flag=0;
  if(scalar(@files)>0)
  {
    my $firstfile=$files[0];
    if($firstfile=~/^(.+?)\/[^\/]+$/){$stubdir=$1;$dir.="/$stubdir";}
  }
  my $hfile=$core->flags("LCG_DICT_HEADER");
  my $xfile=$core->flags("LCG_DICT_XML");
  if($hfile=~/^\s*$/)
  {
    if($stubdir ne ""){$hfile="${stubdir}/classes.h";}
    else{$hfile="classes.h";}
  }
  if($xfile=~/^\s*$/)
  {
    if($stubdir ne ""){$xfile="${stubdir}/classes_def.xml";}
    else{$xfile="classes_def.xml";}
  }
  my $h1="";
  my $x1="";
  my @h=();
  my @x=();
  foreach my $f (split /\s+/,$hfile){if(-f "${path}/${f}"){$h1.="$f ";push @h,"${top}/${path}/${f}";$flag|=1;}}
  foreach my $f (split /\s+/,$xfile){if(-f "${path}/${f}"){$x1.="$f ";push @x,"${top}/${path}/${f}";$flag|=2;}}
  if ((scalar(@h) == scalar(@x)) && ($flag==3))
  {
    for(my $i=0;$i<scalar(@h);$i++)
    {
      my $f=$h[$i]; $f=~s/^.+?\/([^\/]+)$/$1/;$f=~s/^(.+)\.[^\.]+$/$1/;
      push @$headers,$f;
      push @$lcgheader,$h[$i];
      push @$lcgxml,$x[$i];
    }
    my $tmp = $core->flags("ROOTMAP");
    if($tmp=~/^\s*(yes|1)\s*$/i){$rootmap=1;}
    $tmp = $core->flags("GENREFLEX_ARGS");
    if($tmp=~/^\s*\-\-\s*$/){$genreflex_args="";}
    elsif($tmp!~/^\s*$/){$genreflex_args=$tmp;}
    $tmp = $core->flags("GENREFLEX_FAILES_ON_WARNS");
    if($tmp!~/^\s*(no|0)\s*$/i){$genreflex_args.=" --fail_on_warnings";}
    my $plugin=$stash->get('plugin_name');
    my $libname=$stash->get('safename');
    if(($plugin ne "") && ($plugin eq $libname))
    {
      my @bf=keys %{$stash->get('core.bfdeps()')};
      print STDERR "****ERROR: One should not set SEAL_PLUGIN_NAME or SEALPLUGIN flag for a library which is also going to generate LCG dictionaries.\n";
      print STDERR "           Please take appropriate action to fix this by either removing the\n";
      print STDERR "           SEAL_PLUGIN_NAME or SEALPLUGIN flag from the \"$bf[@bf-1]\" file for library \"$libname\"\n";
      print STDERR "           OR LCG DICT header/xml files for this seal plugin library.\n";
      if((exists $ENV{RELEASETOP}) && ($ENV{RELEASETOP} ne "")){exit 1;}
    }
  }
  elsif($flag>0){print STDERR "****WARNING: Not going to generate LCG DICT from \"$path\" because NO. of .h (\"$h1\") does not match NO. of .xml (\"$x1\") files.\n";}
  my $dref;
  my $bn=$self->{cache}{BuildFile};
  opendir($dref, $dir) || die "ERROR: Can not open \"$dir\" directory. \"${path}/${bn}\" is refering for files in this directory.";
  foreach my $file (readdir($dref))
  {
    if($file=~/.*?LinkDef\.h$/)
    {
      if($stubdir ne ""){$file="${stubdir}/${file}";}
      $rootdict.=" $file";
    }
  }
  closedir($dref);
  $stash->set('classes_def_xml', $lcgxml);
  $stash->set('classes_h', $lcgheader);
  $stash->set('headers', $headers);
  $stash->set('rootmap', $rootmap);
  $stash->set('genreflex_args', $genreflex_args);
  $stash->set('rootdictfile', $rootdict);
  return;
}

sub isDataDownloadCopy ()
{
  my $self=shift;
  my $stash=$self->{context}->stash();
  my $add_download=0;my $add_data_copy=0;
  my $datapath=$stash->get('datapath');
  if (-d $datapath)
  {
    my $urls=();
    foreach my $file (@{&readDir($datapath,2,-1)})
    {if($file=~/\/download\.url$/){push @$urls,$file;$add_download=1;}}
#lange- turn off downloads now - distribute separately
#    if($add_download){$stash->set('downloadurls',$urls);}
#lange - turn off copy of data for now
#    if($ENV{RELEASETOP} eq ""){$add_data_copy=1;}
  }
  $stash->set('add_data_copy',$add_data_copy);
  $stash->set('add_download',$add_download);
  if($add_data_copy || $add_download){return 1;}
  return 0;
}

sub fixProductName ()
{
  my $self=shift;
  my $name=shift;
  if($name=~/^.+?\/([^\/]+)$/)
  {print STDERR "WARNING: Product name should not have \"/\" in itSetting $name=>$1\n";$name=$1;}
  return $name;
}

sub doLCGWrapperStuff ()
{
  my $self=shift;
  my $bfile="$ENV{LOCALTOP}/src/scramv1_buildfiles";
  if((!-f "$bfile") && (-d "$ENV{LOCALTOP}/scramv1"))
  {
    if(!-f "$ENV{LOCALTOP}/config/obviate_buildfiles.pl")
    {die "Missing $ENV{LOCALTOP}/config/obviate_buildfiles.pl file";}
    my $argv="";
    foreach my $arg (@ARGV){$argv.=" $arg";}
    system("$ENV{LOCALTOP}/config/obviate_buildfiles.pl -d $ENV{LOCALTOP}/src -v");
    system("gtar -c -C $ENV{LOCALTOP}/scramv1 ./ --exclude CVS | gtar -x -C $ENV{LOCALTOP}");
    system("touch $bfile");
    system("touch dummy.conf");
    exec ("scramv1 setup -f dummy.conf self; rm -f dummy.conf; scramv1 b -r $argv");
  }
}

sub getGenReflexPath ()
{
  my $self=shift;
  my $genrflx="";
  foreach my $t ("ROOTRFLX","ROOTCORE")
  {
    if(exists $self->{cache}{ToolVariables}{"${t}_BASE"})
    {$genrflx="\$(${t}_BASE)/root/bin/genreflex";last;}
  }
  return $genrflx;
}

sub getRootCintPath ()
{
  my $self=shift;
  my $cint="";
  foreach my $t ("ROOTCORE", "ROOTRFLX")
  {
    if(exists $self->{cache}{ToolVariables}{"${t}_BASE"})
    {$cint="\$(${t}_BASE)/bin/rootcint";last;}
  }
  return $cint;
}

sub shouldSkipForDoc ()
{
  my $self=shift;
  my $name=$self->{core}->name();
  if($name=~/^(domain|doc)$/){return 1;}
  return 0;
}

#############################################3
# Source Extenstions
sub setPythonProductStore ()
{
  my $self=shift;
  my $val=shift || return;
  $self->{cache}{PythonProductStore}=$val;
  return;
}

sub setValidSourceExtensions ()
{
  my $self=shift;
  my $stash = $self->{context}->stash();
  my $class = $stash->get('class');
  my %exts=();
  my @exttypes=$self->getSourceExtensionsTypes();
  my %unknown=();
  foreach my $t (@exttypes){$exts{$t}=[];}
  if ($class eq "LIBRARY")
  {
    foreach my $t (@exttypes)
    {
      foreach my $e ($self->getSourceExtensions($t))
      {push @{$exts{$t}},$e;}
    }
  }
  elsif($class eq "PYTHON")
  {
    foreach my $e ($self->getSourceExtensions("cxx"))
    {push @{$exts{cxx}},$e;}
  }
  elsif($class ne "JAVA")
  {
    my %tmp=();
    foreach my $f (split /\s+/,$self->{core}->productfiles())
    {
      if($f=~/\.([^\.]+)$/)
      {
        my $ext=$1;
	if(exists $tmp{$ext}){next;}
	$tmp{$ext}=1;
	my $found=0;
	foreach my $t (@exttypes)
	{
	  if(exists $self->{cache}{SourceExtensions}{$t}{$ext})
	  {
	    push @{$exts{$t}},$ext;
	    $found=1;
	  }
	}
	if(!$found)
	{
	  $unknown{$ext}=1;
	  print STDERR "ERROR: The file \"$f\" has extensions \"$ext\" which is not supported yet.\n";
	  print STDERR "       Followings are the valid extensions:\n";
	  foreach my $t (@exttypes)
	  {print STDERR "         $t: ",$self->getSourceExtensionsStr($t),"\n";}
	  print STDERR "       Please either rename your file to match one of the above mentioned\n";
	  print STDERR "       extensions OR contact the releasse manager to support \"$ext\" too.\n";
	}
      }
    }
  }
  foreach my $t (@exttypes)
  {
    my $tn="${t}Extensions";
    $stash->set($tn,$exts{$t});
  }
  my $un=[];
  foreach my $e (keys %unknown){push @{$un},$e;}
  $stash->set("unknownExtensions",$un);
  return;
}

sub addSourceExtensionsType()
{
  my $self=shift;
  my $type=lc(shift) || return;
  if(!exists $self->{cache}{SourceExtensions}{$type})
  {$self->{cache}{SourceExtensions}{$type}={};}
  return;
}

sub removeSourceExtensionsType()
{
  my $self=shift;
  my $type=lc(shift) || return;
  delete $self->{cache}{SourceExtensions}{$type};
  return;
}

sub getSourceExtensionsTypes()
{
  my $self=shift;
  return keys %{$self->{cache}{SourceExtensions}};
}

sub addSourceExtensions ()
{
  my $self=shift;
  my $type=lc(shift) || return;
  foreach my $e (@_)
  {$self->{cache}{SourceExtensions}{$type}{$e}=1;}
  return;
}

sub removeSourceExtensions ()
{
  my $self=shift;
  my $type=lc(shift) || return;
  if(exists $self->{cache}{SourceExtensions}{$type})
  {
    foreach my $e (@_)
    {delete $self->{cache}{SourceExtensions}{$type}{$e};}
  }
  return;
}

sub getSourceExtensions ()
{
  my $self=shift;
  my @ext=();
  my $type=lc(shift) || return @ext;
  if(exists $self->{cache}{SourceExtensions}{$type})
  {@ext=keys %{$self->{cache}{SourceExtensions}{$type}};}
  return @ext;
}

sub getSourceExtensionsStr ()
{return join(" ",&getSourceExtensions(@_));}
#########################################
sub depsOnlyBuildFile
{
  my $self=shift;
  my $stash=$self->{context}->stash();
  my $cache=$stash->get("branch")->branchdata();
  if(defined $cache)
  {
    my $src=$ENV{SCRAM_SOURCEDIR};
    my $path=$stash->get("path");
    my $pack=$path; $pack=~s/^$src\///;
    my $sname=$stash->get("safepath");
    my $ex=$self->{core}->data("EXPORT");
    my $fname=".SCRAM/$ENV{SCRAM_ARCH}/MakeData/DirCache/${sname}.mk";
    my $fref;
    open($fref,">$fname") || die "Can not open file for writing: $fname";
    print $fref "ifeq (\$(strip \$($pack)),)\n";
    print $fref "$sname := self/${pack}\n";
    print $fref "$pack  := $sname\n";
    print $fref "${sname}_BuildFile    := \$(WORKINGDIR)/cache/bf/${path}/",$self->{cache}{BuildFile},"\n";
    if (defined $ex)
    {
      foreach my $type ("INCLUDE", "LIB", "USE")
      {
        my $value="";
	my $data=$self->getCacheData($type) || [];
	$value=join(" ",@$data)." ";
	$data=$self->fixData($self->{core}->value($type,$ex),$type,"${path}/".$self->{cache}{BuildFile},1) || [];
	$value.=join(" ",@$data);
	if($value!~/^\s*$/)
	{
	  print $fref "${sname}_EX_${type} := $value\n";
	}
      }
      print $fref "\$(foreach x,\$(sort \$(${sname}_LOC_USE) \$(${sname}_EX_USE)),\$(eval \$(x)_USED_BY += ${sname}))\n";
    }
    print $fref "ALL_EXTERNAL_PRODS += ${sname}\n";
    print $fref "${sname}_INIT_FUNC += \$\$(eval \$\$(call EmptyPackage,$sname))\nendif\n\n";
    close($fref);
    $cache->{MKDIR}{"$ENV{LOCALTOP}/.SCRAM/MakeData/DirCache"}=1;
  }
  return;
}

#########################################
# Util functions
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

sub findActualPath ()
{
  my $file=shift;
  if(-l $file)
  {
    my $dir=dirname($file);
    $file=readlink($file);
    if($file!~/^\//){$file="${dir}/${file}";}
    return &findActualPath($file);
  }
  return $file;
}

sub readDir ()
{
  my $dir=shift;
  my $type=shift;
  my $depth=shift;
  my $data=shift || undef;
  if(!defined $type){$type=0;}
  if(!defined $depth){$type=1;}
  my $first=0;
  if(!defined $data){$data=[];$first=1;}
  my $dref;
  opendir($dref,$dir) || die "Can not open directory $dir for reading.";
  foreach my $f (readdir($dref))
  {
    if(($f eq ".") || ($f eq "..")){next;}
    $f="${dir}/${f}";
    if((-d "$f") && ($depth != 1))
    {&readDir("$f",$type,$depth-1,$data);}
    if($type == 0){push @$data,$f;}
    elsif(($type == 1) && (-d "$f")){push @$data,$f;}
    elsif(($type == 2) && (-f "$f")){push @$data,$f;}
  }
  closedir($dref);
  if($first){return $data;}
}

sub runToolFunction ()
{
  my $self=shift;
  my $func=shift || return "";
  my $tool=shift || "self";
  if($tool eq "self"){$tool=$ENV{SCRAM_PROJECTNAME};}
  $tool=lc($tool);
  $func.="_${tool}";
  if(exists &$func){return $self->$func(@_);}
  return "";
}

sub runFunction ()
{
  my $func=shift || return "";
  if(exists &$func){return &$func(@_);}
  elsif($func=~/^initTemplate_(.+)$/){return &initTemplate_common2all (@_);}
  else{print STDERR "WRANING: Coulld not find the func \"$func\".\n";}
  return "";
}

#############################################
# generating library safe name for a package
#############################################
sub setLCGProjectLibPrefix ()
{my $self=shift;$self->{cache}{LCGProjectLibPrefix}=shift;}
sub safename_pool (){return &safename_LCGProjects(shift,shift,$self->{cache}{LCGProjectLibPrefix});}
sub safename_seal (){return &safename_LCGProjects(shift,shift,$self->{cache}{LCGProjectLibPrefix});}
sub safename_coral (){&safename_LCGProjects(shift,shift,$self->{cache}{LCGProjectLibPrefix});}
sub safename_LCGProjects ()
{
  my $self=shift;
  my $dir=shift;
  my $prefix=shift || "lcg_";
  my $sname=$prefix;
  my $class=$self->{context}->stash()->get('class');
  if ($class eq "LIBRARY"){$sname.=basename(dirname($dir));}
  elsif($class eq "PYTHON"){$sname.="Py".basename(dirname($dir));}
  else{$sname.=basename($dir);}
  return $sname;
}

sub safename_ignominy (){return &safename_CMSProjects(shift,"safename_PackageBased",shift);}
sub safename_iguana (){return &safename_CMSProjects(shift,"safename_SubsystemPackageBased",shift);}
sub safename_cmssw (){return &safename_CMSProjects(shift,"safename_SubsystemPackageBased",shift);}
sub safename_default (){return &safename_CMSProjects(shift,"safename_SubsystemPackageBased",shift);}

sub safename_CMSProjects ()
{
  my $self=shift;
  my $func=shift;
  my $dir=shift;
  my $class=$self->{context}->stash()->get('class');
  if (($class eq "LIBRARY") || ($class eq "PYTHON"))
  {
    my $src=$ENV{SCRAM_SOURCEDIR};
    my $rel=quotemeta($ENV{LOCALTOP});
    $dir=dirname($dir);
    $dir=~s/^${rel}\/${src}\/(.+)$/$1/;
    my $val=&$func($dir);
    if($class eq "PYTHON"){$val="Py$val";}
    return $val;
  }
  return "";
}

sub safename_PackageBased ()
{
  my $dir=shift;
  if($dir=~/^([^\/]+)\/([^\/]+)$/){return "${2}";}
  return "";
}

sub safename_SubsystemPackageBased ()
{
  my $dir=shift;
  if($dir=~/^([^\/]+)\/([^\/]+)$/){return "${1}${2}";}
  return "";
}
########################################
sub addCacheData ()
{
  my $self=shift;
  my $name=shift || return;
  my $value=shift || "";
  $self->{cache}{CacheData}{$name}=$value;
  return;
}

sub getCacheData ()
{
  my $self=shift;
  my $name=shift || return "";
  if(exists $self->{cache}{CacheData}{$name}){return $self->{cache}{CacheData}{$name};}
  return "";
}

######################################
# Template initialization for different levels
sub initTemplate_PROJECT ()
{
  my $self=shift;
  my $ltop=$ENV{LOCALTOP};
  my $odir=$ltop;
  if(-f ".SCRAM/$ENV{SCRAM_ARCH}/ToolCache.db")
  {
    $self->{cache}{toolcache}=&Cache::CacheUtilities::read(".SCRAM/$ENV{SCRAM_ARCH}/ToolCache.db");
    my $odir1=$self->{cache}{toolcache}{topdir};
    if($odir1 ne "")
    {
      $odir=$odir1;
      $odir1=&fixPath($odir);
      if($odir1 ne $ltop)
      {
	if((scalar(@ARGV)==0) || ($ARGV[0] ne "ProjectRename"))
	{
	  my $dummyfile="$ENV{SCRAM_INTwork}/localtopchecking.$$";
          while(-f "${odir1}/${dummyfile}"){$dummyfile.="x";}
          my $fref;
          open($fref,">${ltop}/${dummyfile}") || die "Can not create file under \"${ltop}/$ENV{SCRAM_INTwork}\" directory.";
          close($fref);
          if (-f "${odir1}/${dummyfile}")
          {
            unlink "${ltop}/${dummyfile}";
	    $ltop=$odir1;
          }
          else
          {
            unlink "${ltop}/${dummyfile}";
	    print STDERR "**** ERROR: You have moved/renamed this project area \"$ltop\" from \"$odir1\".\n";
	    print STDERR "            Please first run \"scramv1 b ProjectRename\" command.\n";
	    exit 1;
          }
	}
      }
    }
  }
  my $stash=$self->{context}->stash();
  $self->{cache}{SymLinkPython}=0;
  $self->{cache}{ProjectName}=$ENV{SCRAM_PROJECTNAME};
  $self->{cache}{LocalTop}=$ltop;
  $self->{cache}{ProjectConfig}="${ltop}/$ENV{SCRAM_CONFIGDIR}";
  $self->initTemplate_common2all();
  $stash->set('ProjectLOCALTOP',$ltop);
  $stash->set('ProjectOldPath',$odir);
  my $bdir="${ltop}/$ENV{SCRAM_INTwork}/cache";
  system("mkdir -p ${bdir}/prod ${bdir}/bf ${bdir}/log");
  if((exists $ENV{RELEASETOP}) && ($ENV{RELEASETOP} ne "")){$stash->set('releasearea',0);$self->{cache}{ReleaseArea}=0;}
  else{$stash->set('releasearea',1);$self->{cache}{ReleaseArea}=1;}
  if(!-d "${ltop}/external/$ENV{SCRAM_ARCH}")
  {
    system("${ltop}/$ENV{SCRAM_CONFIGDIR}/linkexternal.pl --arch $ENV{SCRAM_ARCH}");
    system("mkdir -p ${ltop}/external/$ENV{SCRAM_ARCH}");
  }
  $self->{cache}{LCGProjectLibPrefix}="lcg_";
  $self->{cache}{IgLetFile}="iglet.cc";
  $self->{cache}{CXXCompiler}="cxxcompiler";
  $self->{cache}{CCompiler}="ccompiler";
  $self->{cache}{F77Compiler}="f77compiler";
  if ((exists $ENV{SCRAM_BUILDFILE}) && ($ENV{SCRAM_BUILDFILE} ne ""))
  {$self->{cache}{BuildFile}=$ENV{SCRAM_BUILDFILE};}
  else{$self->{cache}{BuildFile}="BuildFile";}
  return;
}

sub initTemplate_PACKAGE ()
{
  my $self=shift;
  $self->initTemplate_common2all();
  my $stash=$self->{context}->stash();
  my $path=$stash->get("path");
  my $suffix=$stash->get("suffix");
  if($suffix eq "")
  {
    my $logdir="$ENV{SCRAM_INTwork}/cache/log/${path}";
    $stash->set('logfile', "${logdir}/build.log");
    $stash->set('logdir', $logdir);
  }
  $path=~s/^src\///;
  $stash->set('packpath',$path);
  $self->depsOnlyBuildFile();
  return;
}

sub initTemplate_LIBRARY ()
{
  my $self=shift;
  $self->initTemplate_common2all();
  my $stash=$self->{context}->stash(); 
  my $path=$stash->get('path');
  my $sname=$self->runToolFunction("safename","self", "$ENV{LOCALTOP}/${path}");
  if($sname eq "")
  {
    $self->processTemplate("safename_generator");
    $sname=$stash->get('safename');
    if($sname eq ""){$sname=$self->runToolFunction("safename","default", "$ENV{LOCALTOP}/${path}");}
  }
  if($sname ne ""){$stash->set("safename", $sname);}
  else
  {
    print STDERR "*** ERROR: Unable to generate library safename for package \"$path\" of project $ENV{SCRAM_PROJECTNAME}\n";
    print STDERR "    Please either update the $ENV{SCRAM_PROJECTNAME}_safename_generator.tmpl file to properly generate\n";
    print STDERR "    safename for this project or add the support for this project in this built template plugin.\n";
    exit 1;
  }
  if(exists $self->{cache}{IgLetFile})
  {
    my $file=$self->{cache}{IgLetFile};
    if(-f "${path}/${file}")
    {$stash->set("iglet_file",$file);}
  }
  return;
}

sub initTemplate_SEAL_PLATFORM ()
{
  my $self=shift;
  $self->initTemplate_common2all();
  my $stash=$self->{context}->stash(); 
  $stash->set("safename", "SealPlatform");
  return;
}

sub initTemplate_PYTHON ()
{return &initTemplate_LIBRARY(shift);}
 
sub initTemplate_common2all ()
{
  my $self=shift;
  my $stash=$self->{context}->stash();
  $stash->set("ProjectName",$self->{cache}{ProjectName});
  $stash->set("ProjectConfig",$self->{cache}{ProjectConfig});
  return;
}

1;
