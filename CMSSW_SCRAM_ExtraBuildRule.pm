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
  $common->symlinkPythonDirectory(1);
  $common->addPluginSupport("iglet","IGLET","IgPluginRefresh",'\/iglet$',"SCRAMSTORENAME_LIB",".iglets",'$name="${name}.iglet"',"yes");
  $common->addPluginSupport("edm","EDM_PLUGIN","EdmPluginRefresh",'\/plugins$',"SCRAMSTORENAME_LIB",".edmplugincache",'$name="${name}.edmplugin"',"yes");
  $common->setProjectDefaultPluginType ("edm");
  $common->setLCGCapabilitiesPluginType ("edm");
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
            "\t\@cd \$(LOCALTOP); \\\n",
            "\tmkdir src/.glimpse_full; \\\n",
            "\tglimpseindex -F -H src/.glimpse_full src; \\\n",
            "\tcd src; \\\n",
            "\t/bin/bash ../config/fixindices.sh;\n";
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
  else{$common->set("plugin_name",$common->core()->flags("SEAL_PLUGIN_NAME"));$common->plugin_template();}
  $common->pushstash();$common->lexyacc_template();$common->popstash();
  $common->pushstash();$common->codegen_template();$common->popstash();
  $common->pushstash();$common->dict_template();   $common->popstash();
  return 1;
}

sub Classlib_template ()
{
  my $self=shift;
  my $common=$self->{template};
  if ($common->get("suffix") ne ""){return 1;}
  $common->initTemplate_common2all();
  my $safename="classlib";
  $common->set("safename",$safename);
  my $core=$common->core();
  my $types=$core->buildproducts();
  if($types)
  {
    foreach my $type (keys %$types)
    {
      $common->set("type",$type);
      $common->unsupportedProductType();
    }
  }
  my $path=$common->get("path"); my $safepath=$common->get("safepath");
  my $parent=$common->get("parent");
  my $fh=$common->filehandle();
  $core->branchdata()->name($safename);
  print $fh "ifeq (\$(strip \$($parent)),)\n",
            "${safename} := self/${parent}\n",
            "${parent} := ${safename}\n",
	    "${safename}_XDEPS := \$(WORKINGDIR)/\$(SCRAM_SOURCEDIR)/${parent}/${safename}.headers\n";
  $common->pushstash();$common->library_template_generic();$common->popstash();
  print $fh "${safename}_INIT_FUNC := \$\$(eval \$\$(call LogFile,${safename},${path}))\n",
            "${safename}_INIT_FUNC += \$\$(eval \$\$(call ClassLib,${safename},\$(SCRAM_SOURCEDIR)/${parent},${safepath}))\n",
            "endif\n";
  
  my $confstr="./configure -C CPPFLAGS=\"\$\$(\$(1)_CPPFLAGS)\" ".
            "CC=\"\$\$(strip \$(CC))\" CXX=\"\$\$(strip \$(CXX))\" CFLAGS=\"\$\$(strip \$\$(\$(1)_LOC_FLAGS_CFLAGS_ALL))\" ".
            "CXXFLAGS=\"\$\$(\$(1)_CXXFLAGS)\" LIBS=\"\$\$(\$(1)_LOC_LIB_ALL:%=-l%)\" LDFLAGS=\"\$\$(\$(1)_LOC_LIBDIR_ALL:%=-L%)\" ".
            "--prefix=\$(LOCALTOP) --libdir=\$(LOCALTOP)/\$(SCRAMSTORENAME_LIB) ".
            "--includedir=\$(LOCALTOP)/\$(SCRAMSTORENAME_INCLUDE) ".
            "--with-zlib   --with-zlib-includes=\$(ZLIB_BASE)/include      --with-zlib-libraries=\$(ZLIB_BASE)/lib ".
            "--with-bz2lib --with-bz2lib-includes=\$(BZ2LIB_BASE)/include  --with-bz2lib-libraries=\$(BZ2LIB_BASE)/lib ".
            "--with-pcre   --with-pcre-includes=\$(PCRE_BASE)/include      --with-pcre-libraries=\$(PCRE_BASE)/lib ".
            "--with-uuid   --with-uuid-includes=\$(UUID_BASE)/include/uuid --with-uuid-libraries=\$(UUID_BASE)/lib";

  my $xfhn = "$ENV{LOCALTOP}/$ENV{SCRAM_INTwork}/MakeData/ExtraBuilsRules";
  if (!-d $xfhn){system("mkdir -p $xfhn");}
  $xfhn.="/${safename}.mk";
  my $xfh=undef;
  open ($xfh,">$xfhn") || die "Can not open file for writing: $xfhn";
  #safename,path,safepath,prodarea
  print $xfh "define ClassLib\n",
            ".PHONY: all_\$(3) all_\$(1) \$(3) \$(1)\n",
            "all_\$(3) all_\$(1) \$(1) \$(3): \$(WORKINGDIR)/\$(2)/\$(1).installed\n",
            "\$(WORKINGDIR)/cache/prod/lib\$(1): \$(WORKINGDIR)/\$(2)/\$(1).installed\n",
            "\t\@if [ ! -f \$\$@ ] ; then touch \$\$@; fi\n",
            "\$(WORKINGDIR)/\$(2)/configure: \$(CONFIGDEPS) \$(logfile_\$(1)) \$(\$(1)_BuildFile) \$(LOCALTOP)/\$(2)/configure\n",
	    "\t\@\$(startlog_\$(1))mkdir -p \$\$(dir \$(WORKINGDIR)/\$(2)) &&\\\n",
            "\tif [ -d \$(WORKINGDIR)/\$(2) ] ; then \\\n",
            "\t  rm -rf \$(WORKINGDIR)/\$(2) ;\\\n",
            "\tfi &&\\\n",
            "\tcp -r \$(LOCALTOP)/\$(2) \$\$(dir \$(WORKINGDIR)/\$(2)) \$(endlog_\$(1))\n",
            "\$(WORKINGDIR)/\$(2)/\$(1).configured: \$(WORKINGDIR)/\$(2)/configure\n",
            "\t\@echo \">> Configuring \$2\"\n",
	    "\t\@\$(startlog_\$(1))mkdir -p \$\$(\@D);\\\n",
            "\tcd \$\$(<D); \\\n",
	    "\techo $confstr &&\\\n",
	    "\t$confstr &&\\\n",
            "\tcd \$(LOCALTOP) && touch \$\$@ \$(endlog_\$(1))\n",
            "\$(WORKINGDIR)/\$(2)/\$(1).made: \$(WORKINGDIR)/\$(2)/\$(1).configured\n",
            "\t\@echo \">> Compiling \$2\"\n",
	    "\t\@\$(startlog_\$(1))cd \$(WORKINGDIR)/\$(2); \$\$(MAKE) &&\\\n",
            "\tcd \$(LOCALTOP) && touch \$\$@ \$(endlog_\$(1))\n",
            "\$(WORKINGDIR)/\$(2)/\$(1).installed: \$(WORKINGDIR)/\$(2)/\$(1).made \$(WORKINGDIR)/\$(2)/\$(1).headers\n",
            "\t\@echo \">> Installing library \$2\"\n",
	    "\t\@\$(startlog_\$(1))cd \$(WORKINGDIR)/\$(2); \$\$(MAKE) install-exec &&\\\n",
            "\tcd \$(LOCALTOP) && rm -f \$(SCRAMSTORENAME_LIB)/lib\$(1).la && touch \$\$@ \$(endlog_\$(1))\n",
            "\$(WORKINGDIR)/\$(2)/\$(1).headers: \$(WORKINGDIR)/\$(2)/\$(1).configured\n",
            "\t\@echo \">> Installing headers \$2\"\n",
            "\t\@\$(startlog_\$(1))cd \$(WORKINGDIR)/\$(2); \$\$(MAKE) install-data &&\\\n",
            "\tcd \$(LOCALTOP) && touch \$\$@ \$(endlog_\$(1))\n",
            "endef\n";
  close($xfh);
  return 1;
}

1;
