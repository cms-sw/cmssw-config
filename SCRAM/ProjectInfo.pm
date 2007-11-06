package SCRAM::ProjectInfo;
require 5.004;

sub new()
   {
   my $proto=shift;
   my $class=ref($proto) || $proto;
   my $self={};
   $self->{project}=lc($ENV{SCRAM_PROJECTNAME});
   bless $self,$class;
   return $self;
   }

sub ispublic ()
   {
   my $self = shift;
   my $item = shift;
   my $class = $item->class();
   my $proj=$self->{project};
   if ($class eq "LIBRARY") {return 1;}
   elsif($class eq "SEAL_PLATFORM"){return 1;}
   elsif($class eq "CLASSLIB"){return 1;}
   return 0;
   }

   
1;
