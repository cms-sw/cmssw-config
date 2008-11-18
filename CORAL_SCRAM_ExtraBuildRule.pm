package SCRAM_ExtraBuildRule;
require 5.004;
use Exporter;
@ISA=qw(Exporter);

sub new()
{
  my $class=shift;
  my $self={};
  $self->{template}=shift;
  bless($self, $class);
  return $self;  
}

sub isPublic ()
   {
   my $self=shift;
   my $class = shift;
   if ($class eq "LIBRARY") {return 1;}
   elsif($class eq "SEAL_PLATFORM"){return 1;}
   elsif($class eq "CLASSLIB"){return 1;}
   return 0;
   }

sub Project ()
{
  my $self=shift;
  my $common=$self->{template};
  my $fh=$common->filehandle();
  my $hasseal=$common->isToolAvailable("seal");
  if ($hasseal)
  {
    $common->addPluginSupport("seal","SEALPLUGIN","SealPluginRefresh",'\/plugins$',"SCRAMSTORENAME_LIB_MODULES",".cache",'$name="${name}.reg"',"");
    $common->addPluginDirMap("seal",'\/tests$',"SCRAMSTORENAME_TESTS_LIB_MODULES");
  }
  else{$common->removePluginSupport("seal");}
  $common->addProductDirMap("bin",'\/tests$',"SCRAMSTORENAME_TESTS_BIN",1);
  $common->addProductDirMap("bin",'^src\/Tests\/.+',"SCRAMSTORENAME_TESTS_BIN",1);
  $common->addProductDirMap("lib",'\/tests$',"SCRAMSTORENAME_TESTS_LIB",1);
  $common->addProductDirMap("lib",'^src\/Tests\/.+',"SCRAMSTORENAME_TESTS_LIB",1);
  print $fh "CONFIGDEPS += \$(WORKINGDIR)/cache/project_includes\n",
            "\$(WORKINGDIR)/cache/project_includes: FORCE_TARGET\n",
            "\t\@for f in \$(SCRAM_SOURCEDIR)/*; do        \\\n",
            "\t  name=`basename \$\$f`;				\\\n",
            "\t  f=\$\$f/\$\$name;					\\\n",
            "\t  [ -d \$\$f ] || continue;                       \\\n",
            "\t  if [ ! -e \$(LOCALTOP)/include/\$\$name ] ; then	\\\n",
            "\t    ln -s ../\$\$f include/\$\$name ;	        \\\n",
            "\t  fi; 						\\\n",
            "\tdone\n",
            "\t\@if [ ! -f \$@ ] ; then touch \$@; echo \$(\@F) DONE; fi\n\n";
  return 1;
}

sub Extra_template()
{
  my $self=shift;
  my $common=$self->{template};
  if ($common->isToolAvailable("seal"))
  {
    $common->set("plugin_name",$common->core()->flags("SEAL_PLUGIN_NAME"));
    $common->plugin_template();
  }
  $common->pushstash();$common->rootmap($common->core()->flags("ROOTMAP"));$common->popstash();
  return 1;
}

1;
