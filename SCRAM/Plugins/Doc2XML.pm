package SCRAM::Plugins::Doc2XML;
require 5.004;

sub new()
   {
   my $proto=shift;
   my $class=ref($proto) || $proto;
   my $self={};
   bless $self,$class;
   $self->init_();
   return $self;
   }

sub init_ ()
   {
   my $self=shift;
   $self->{output}=[];
   foreach my $tag ("project","config","download","requirementsdoc","base",
                    "tool","client","environment","runtime","productstore","classpath",
		    "use","flags","architecture","lib","bin","library",
		    "include","select","require","include_path")
      {
      $self->{tags}{$tag}{map}="defaultprocessing";
      }
   foreach   my $tag ("base","tool","client","architecture","bin","library","project","makefile","export","environment")
      {
      $self->{tags}{$tag}{close}=1;
      }
   foreach my $tag ("export","client","environment") 
      {
      $self->{tags}{$tag}{map}="defaultsimple";
      }
   }
   
sub convert()
   {
   my $self=shift;
   my $file=shift;
   $self->{filename}=$file;
   $self->{input}=[];
   my $fref;
   open($fref,$file) || die "Can not open file for reading: $file";
   while(my $line=<$fref>)
      {
      chomp $line;
      push @{$self->{input}},$line;
      }
   close($fref);
   $self->{count}=scalar(@{$self->{input}});
   $self->process_();
   $self->{input}=[];
   return $self->{output};
   }

sub clean ()
   {
   my $self=shift;
   $self->{outout}=[];
   }
   
sub lastTag ()
   {
   my $tags=shift;
   pop @$tags;
   my $count=scalar(@$tags);
   if ($count>0)
      {
      return $tags->[$count-1];
      }
   return "";
   }
   
sub process_()
   {
   my $self=shift;
   my $num=0;
   my $count=$self->{count};
   my $file=$self->{filename};
   my $line="";
   my @tags=();
   my $ltag="";
   my $pline="";
   my $err=0;
   while ($line || (($num<$count) && (($line=$self->{input}[$num++]) || 1)))
      {
      if ($line=~/^\s*#/){$line="";next;}
      if ($line=~/^\s*$/){$line="";next;}
      if ($line eq $pline)
         {
	 $err++;
	 if($err>10)
	   {last;}
	 }
      else{$err=0;}
      $pline=$line;
      #print STDERR "LINE:$line:$num:$count:$ltag\n";
      if ($line=~/^\s*<\s*(\/\s*doc\s*|doc\s+[^>]+)>(.*)$/i){$line=$2;next;}
      if ($line=~/^(\s*<\s*\/\s*([^\s>]+)\s*>)(.*)$/)
      {
        my $tag=lc($2);
	my $nline=lc($1);$nline=~s/\s//g;
	$line=$3;
	if (exists $self->{tags}{$tag}{close})
	   {
	   if (scalar(@tags)>0)
	      {
	      if ($ltag ne $tag)
	         {
		 print STDERR "**** WARNING: Found tag \"$tag\" at line NO. $num of file \"$file\" while looking for \"$ltag\".\n";
		 push @{$self->{output}},"</$ltag>";
		 my $flag=0;
		 foreach my $t (@tags)
		    {
		    if ($t eq $tag){$flag=1;last;}
		    }
		 if ($flag){$line="${nline}${line}";next;}
		 }
	      else
	         {
	         push @{$self->{output}},$nline;
		 }
		 $ltag = &lastTag(\@tags);
	      }
	   else
	      {
	      print STDERR "**** WARNING: Found closing tag \"$tag\" at line NO. $num without any opening tag in file \"$file\".\n";
	      }
	   }
	next;
      }
      if ($line=~/^(\s*<\s*([^\s>]+)\s*>)(.*)$/)
         {
	 my $tag=lc($2);
	 $line=lc($1); $line=~s/\s//g;
	 push @{$self->{output}},$line;
	 push @tags,$tag;
	 $ltag=$tag;
	 $line=$self->do_tag_processing_($tag,$3,\$num);
	 next;
	 }
      if ($line=~/^(\s*<\s*([^\s]+))(\s+.+)/)
         {
	 my $tag=lc($2);
	 if($tag eq "!--")
	   {
	   $line="";
	   next;
	   }
	 if (scalar(@tags)>0)
	    {
	    if ((($tag  eq "bin") || ($tag  eq "library")) &&
	        (($ltag eq "bin") || ($ltag eq "library")))
	       {
	       print STDERR "**** WARNING: Missing closing \"$ltag\" tag at line NO. $num of file \"$file\".\n";
	       push @{$self->{output}},"</$ltag>";
	       $ltag = &lastTag(\@tags);
	       }
	    }
	 $line="<$tag $3";
	 while(($line!~/>/) && ($num<$count))
	    {
	    my $nline=$self->{input}[$num++];
	    if ($nline=~/^\s*</) {print STDERR "**** WARNING: Missing \">\" at line NO. ",$num-1," of file \"$file\".\n==>$line\n";$line.=">";}
	    $line.=$nline;
	    }
	 if ($line!~/>/){print STDERR "**** WARNING: Missing \">\" at line NO. $num of file \"$file\".\n==>$line\n";$line.=">";}
	 $line=$self->do_tag_processing_($tag,$line,\$num);
	 if (exists $self->{tags}{$tag}{close}){push @tags,$tag;$ltag=$tag;}
	 next;
	 }
      elsif ($ltag=~/^(project|bin|library)$/)
         {
	 if ($line=~/^.*<\s*\/\s*$ltag\s*>(.*)/)
	    {
	    push @{$self->{output}},"</$ltag>";
	    $line=$1;
	    $ltag = &lastTag(\@tags);
	    }
	 else{$line="";}
	 }
      else
         {
	 if (($line=~/^(\s*)((lib|use|flags|bin|library)\s*(name|file|[^=]+)\s*=.*)/i) ||
	     ($line=~/^(\s*)((export|client|environment)\s*>.*)/i))
	    {
	    print STDERR "**** WARNING: Missing \"<\" at line NO. $num of file \"$file\".\n==>$line\n";
	    $line="$1<$2";
	    next;
	    }
 	 else
	    {   
	    print STDERR "**** WARNING: Unknown line\n==>$line\nat line NO. $num of file \"$file\".\n";
	    $line="";
	    }
	 }
      }
   while(@tags>0)
      {
      my $t=pop @tags;
      print STDERR "**** WARNING: Missing closing tag \"$t\" in file \"$file\".\n";
      push @{$self->{output}},"</$t>";
      }
   }
   
sub do_tag_processing_ ()
   {
   my $self=shift;
   my $tag=shift;
   my $line=shift;
   my $num=shift;
   my $func="process_${tag}_";
   if (exists $self->{tags}{$tag}{map}){$func="process_".$self->{tags}{$tag}{map}."_";}
   if (!exists &$func)
      {
      print STDERR "**** ERROR: Unable to process the \"$tag\" tag at line NO. ${$num} of file \"",$self->{filename},"\".\n";
      $line="";
      }
   else
      {
      $line=&$func($self,$tag,$line,$num);
      }
   return $line;
   }

sub getnextattrib_()
   {
   my $attr=shift;
   my $num=shift;
   my $line=${$attr};
   my $ret="";
   if ($line=~/^\s*([^\s=]+)\s*=\s*(.*)/)
      {
      $ret="$1=";
      $line=$2;
      if ($line=~/^(["'])(.*)/)
         {
	 my $q=$1;
	 $line=$2;
	 if ($line=~/^(.*?$q)(.*)/)
	    {
	    $ret.="$q$1";
	    $line=$2;
	    }
	 else
	    {
	    print STDERR "**** WARNING: Missing ($q) at line NO. ${$num} of file \"",$self->{filename},"\".\n";
	    $ret.="$q$line$q";
	    $line="";
	    }
	 }
      elsif ($line=~/^([^\s]*)(\s*.*)/)
         {
	 $ret.="\"$1\"";
	 $line=$2;
	 }
      else{$ret.="\"$line\"";$line="";}
      }
   else
   {
     $line=~s/^\s*//;$line=~s/\s*$//;
     $ret="$line=\"\"";
     $line="";
   }
   ${$attr}=$line;
   return $ret;      
   }   
   
sub process_defaultprocessing_
   {
   my $self=shift;
   my $tag=shift;
   my $line=shift;
   my $num=shift;
   my $close=1;
   if(exists $self->{tags}{$tag}{close}){$close=0;}
   my $nline="";
   $line=~/^(\s*<\s*$tag\s+)([^>]+)>(.*)$/;
   $nline=$1; $line=$3;
   my $attrib=$2; $attrib=~s/\s*$//;
   while($attrib!~/^\s*$/)
      {
      my $item=&getnextattrib_(\$attrib,$num);
      my ($key,$value)=split /=/,$item,2;
      if ($value!~/^\"[^\"]*\"$/)
         {
	 if ($value=~/^\'([^\']*)\'$/)
	    {
	    $value=$1;
	    if ($value=~/^\s*\"([^\"]+)\"\s*$/){$value = "'$1'";}
	    }
	 $value = "\"$value\"";
	 }
      $nline.=" $key=$value";
      }
   if($close){$nline.="/>";}
   else{$nline.=">";}
   push @{$self->{output}},$nline;
   return $line;
   }

sub process_defaultsimple_()
   {
   my $self=shift;
   my $tag=shift;
   my $line=shift;
   return $line;
   }
   
sub process_makefile_ ()
   {
   my $self=shift;
   my $tag=shift;
   my $line=shift;
   my $num=shift;
   my $count=$self->{count};
   while ($line || ((${$num}<$count) && (($line=$self->{input}[${$num}++]) || 1)))
      {
      if ($line=~/^<\s*\/\s*$tag\s*>\s*(.*)/)
         {
	 last;
	 }
      elsif ($line=~/^(.+?)(<\s*\/\s*$tag\s*>.*)/)
         {
	 my $l=$1;
	 $line=$2;
	 if($l!~/^\s*$/){push @{$self->{output}},"$l\n";}
	 last;
	 }
      else {push @{$self->{output}},"$line\n";$line="";}
      }
   return $line;
   }
   
1;
