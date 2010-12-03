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

sub Project()
{
  my $self=shift;
  my $common=$self->{template};
  my $fh=$common->filehandle();
  my $hasseal=$common->isToolAvailable("seal");
  if (!$hasseal){$common->removePluginSupport("seal");}
  $common->symlinkPythonDirectory(1);
  $common->addPluginSupport("iglet","IGLET","IgPluginRefresh",'\/iglet$',"SCRAMSTORENAME_LIB",".iglets",'$name="${name}.iglet"',"yes");
  $common->addPluginSupport("edm","EDM_PLUGIN","EdmPluginRefresh",'\/plugins$',"SCRAMSTORENAME_LIB",".edmplugincache",'$name="${name}.edmplugin"',"yes");
  $common->setProjectDefaultPluginType ("edm");
  $common->setLCGCapabilitiesPluginType ("edm");
  print $fh "EDM_WRITE_CONFIG:=edmWriteConfigs\n";
  print $fh "COMPILE_PYTHON_SCRIPTS:=yes\n";
  print $fh "CPPDEFINES+=-DPROJECT_NAME='\"\$(SCRAM_PROJECTNAME)\"' -DPROJECT_VERSION='\"\$(SCRAM_PROJECTVERSION)\"'\n";
  my $g4magic="$ENV{LOCALTOP}/src/SimG4Core/Packaging/g4magic";
  if ((-f $g4magic) && (!-f "${g4magic}.done"))
  {
    print STDERR ">> Updating SimG4Core/Packaging sources by running the g4magic script\n";
    system("/bin/bash $g4magic");
    system("touch ${g4magic}.done");
  }
  print $fh "integration-test:\n",
            "\t\@if [ -f \$(LOCALTOP)/src/Configuration/Applications/data/runall.sh ]; then \\\n",
            "\t echo \">> Running integration test suite\"; echo; \\\n",
            "\t cd \$(LOCALTOP)/src/Configuration/Applications/data; ./runall.sh >/dev/null 2>&1; \\\n",
            "\tfi;\n";
######################################################################
# Dependencies: run ignominy analysis for release documentation
  print $fh ".PHONY: dependencies\n",
            "dependencies:\n",
            "\t\@cd \$(LOCALTOP); eval `scramv1 run -sh`; \\\n",
            "\tmkdir -p \$(LOCALTOP)/doc/deps/\$(SCRAM_ARCH); \\\n",
            "\tcd \$(LOCALTOP)/doc/deps/\$(SCRAM_ARCH); \\\n",
            "\trunignominy -f -d os -A -g all \$(LOCALTOP)\n";
######################################################################
# Documentation targets. Note- must be lower case otherwise conflict with rules
# for dirs which have the same name:
  print $fh ".PHONY: userguide referencemanual doc\n",
            "doc: referencemanual\n",
            "\t\@echo \"Documentation/release notes built for \$(SCRAM_PROJECTNAME) v\$(SCRAM_PROJECTVERSION)\"\n",
            "userguide:\n",
            "\t\@if [ -f \$(LOCALTOP)/src/Documentation/UserGuide/scripts/makedoc ]; then \\\n",
            "\t  doctop=\$(LOCALTOP); \\\n",
            "\telse \\\n",
            "\t  doctop=\$(RELEASETOP); \\\n",
            "\tfi; \\\n",
            "\tcd \$\$doctop/src; \\\n",
            "\tDocumentation/UserGuide/scripts/makedoc \$(LOCALTOP)/src \$(LOCALTOP)/doc/UserGuide \$(RELEASETOP)/src\n",
            "referencemanual:\n",
            "\t\@cd \$(LOCALTOP)/src/Documentation/ReferenceManualScripts/config; \\\n",
            "\tsed -e 's|\@PROJ_NAME@|\$(SCRAM_PROJECTNAME)|g' \\\n",
            "\t-e 's|\@PROJ_VERS@|\$(SCRAM_PROJECTVERSION)|g' \\\n",
            "\t-e 's|\@CMSSW_BASE@|\$(LOCALTOP)|g' \\\n",
            "\t-e 's|\@INC_PATH@|\$(LOCALTOP)/src|g' \\\n",
            "\tdoxyfile.conf.in > doxyfile.conf; \\\n",
            "\tcd \$(LOCALTOP); \\\n",
            "\tls -d src/*/*/doc/*.doc | sed 's|\(.*\).doc|mv \"&\" \"\\1.dox\"|' | /bin/sh; \\\n",
            "\tif [ `expr substr \$(SCRAM_PROJECTVERSION) 1 1` = \"2\" ]; then \\\n",
            "\t  ./config/fixdocs.sh \$(SCRAM_PROJECTNAME)\"_\"\$(SCRAM_PROJECTVERSION); \\\n",
            "\telse \\\n",
            "\t  ./config/fixdocs.sh \$(SCRAM_PROJECTVERSION); \\\n",
            "\tfi; \\\n",
            "\tls -d src/*/*/doc/*.doy |  sed 's/\(.*\).doy/sed \"s|\@PROJ_VERS@|\$(SCRAM_PROJECTVERSION)|g\" \"&\" > \"\\1.doc\"/' | /bin/sh; \\\n",
            "\trm -rf src/*/*/doc/*.doy; \\\n",
            "\tcd \$(LOCALTOP)/src/Documentation/ReferenceManualScripts/config; \\\n",
            "\tdoxygen doxyfile.conf; \\\n",
            "\tcd \$(LOCALTOP); \\\n",
            "\tls -d src/*/*/doc/*.dox | sed 's|\(.*\).dox|mv \"&\" \"\\1.doc\"|' | /bin/sh;\n";
######################################################################
  print $fh ".PHONY: gindices\n",
            "gindices:\n",
            "\t\@cd \$(LOCALTOP)/src; \\\n",
            "\trm -rf  \$(LOCALTOP)/src/.glimpse_full; mkdir  \$(LOCALTOP)/src/.glimpse_full; \\\n",
            "\tls -d \$(LOCALTOP)/src/*/*/*  | glimpseindex -F -H \$(LOCALTOP)/src/.glimpse_full; \\\n",
            "\tfor  x in `ls -A1 .glimpse_full` ; do \\\n",
            "\t  ln -s .glimpse_full/\$\$x \$\$x; \\\n",
            "\tdone; \\\n",
            "\trm .glimpse_filenames; cp .glimpse_full/.glimpse_filenames .glimpse_filenames; \\\n",
            "\tsed -i -e 's|\$(LOCALTOP)/src/||g' .glimpse_filenames\n";
######################################################################
  print $fh ".PHONY: productmap\n",
            "productmap:\n",
            "\t\@cd \$(LOCALTOP); \\\n",
            "\tmkdir -p src; rm -f src/ReleaseProducts.list; echo \">> Generating Product Map in src/ReleaseProducts.list.\";\\\n",
            "\t(RelProducts.pl \$(LOCALTOP) > \$(LOCALTOP)/src/ReleaseProducts.list || exit 0)\n";
######################################################################
  print $fh ".PHONY: depscheck\n",
            "depscheck:\n",
            "\t\@ReleaseDepsChecks.pl --detail\n";
#####################################################################
# python link directory rule over ridden
  if (!$common->isReleaseArea())
  {
    print $fh <<EOD;
override define python_directory_link
  @\$(startlog_\$(2))if [ ! -d \$(LOCALTOP)/\$(3) ]; then \\
    mkdir -p \$(LOCALTOP)/\$(3) &&\\
    echo "Creating product storage directory: \$(LOCALTOP)/\$(3)"; 	\\
  fi &&\\
  if [ ! -e \$(\$(1)_python_dir) ] ; then \\
    subsysdir=`dirname \$(\$(1)_python_dir)` &&\\
    mkdir -p \$\$subsysdir &&\\
    rellink=. &&\\
    subsysdir1=\$\$subsysdir &&\\
    while [ "\$\$subsysdir1" != "." ] ; do \\
      if [ ! -f \$\$subsysdir1/__init__.py ] ; then \\
        touch \$\$subsysdir1/__init__.py ;\\
        if [ "X\$\$subsysdir1" != "X\$3" ] ; then \\
          echo "__path__.append(\\\"$ENV{RELEASETOP}/\$\$subsysdir1\\\")" > \$\$subsysdir1/__init__.py ;\\
        fi ;\\
      fi ;\\
      subsysdir1=`dirname \$\$subsysdir1`;  \\
      rellink=\$\$rellink/..; \\
    done &&\\
    ln -s \$\$rellink/\$(4) \$(\$(1)_python_dir) &&\\
    echo ">> Link created: \$(\$(1)_python_dir) -> \$(\$(1)_srcdir)" &&\\
    for d in . `ls \$(\$(1)_python_dir)` ; do \\
      if [ -d \$(\$(1)_python_dir)/\$\$d ] ; then \\
        if [ ! -f \$(\$(1)_python_dir)/\$\$d/__init__.py ] ; then \\
          echo "#this file was automatically created by SCRAM" > \$(\$(1)_python_dir)/\$\$d/__init__.py; \\
        fi ;\\
      fi ;\\
    done ;\\
  fi \$(endlog_\$(2))
endef
EOD
  }
  return 1;
}

sub Extra_template()
{
  my $self=shift;
  my $common=$self->{template};
  $common->pushstash();$common->moc_template();$common->popstash();
  if ($common->get("iglet_file") ne ""){$common->iglet_template();}
  else
  {
    if ($common->isToolAvailable("seal")){$common->set("plugin_name",$common->core()->flags("SEAL_PLUGIN_NAME"));}
    $common->plugin_template();
  }
  $common->pushstash();$common->lexyacc_template();$common->popstash();
  $common->pushstash();$common->codegen_template();$common->popstash();
  $common->pushstash();$common->dict_template();   $common->popstash();
  return 1;
}

1;
