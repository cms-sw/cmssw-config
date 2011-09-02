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
   return 0;
   }

sub Project ()
{
  my $self=shift;
  my $common=$self->{template};
  $common->addProductDirMap("bin",'\/tests$',"SCRAMSTORENAME_TESTS_BIN",1);
  $common->addProductDirMap("lib",'\/tests$',"SCRAMSTORENAME_TESTS_LIB",1);
  $common->addSymLinks("src include 1 .");
  return 1;
}

sub Extra_template()
{
  my $self=shift;
  my $common=$self->{template};
  $common->pushstash();$common->dict_template();   $common->popstash();
  return 1;
}

1;
