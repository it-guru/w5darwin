package otipci::event::otipci_OriginLoad;
#  W5Base Framework
#  Copyright (C) 2026  Hartmut Vogler (it@guru.de)
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
use strict;
use vars qw(@ISA);
use kernel;
use kernel::Event;
@ISA=qw(kernel::Event);

sub new
{
   my $type=shift;
   my %param=@_;
   my $self=bless($type->SUPER::new(%param),$type);


   return($self);
}

sub Init
{
   my $self=shift;

   $self->RegisterEvent("otipci_OriginLoad","otipci_OriginLoad",timeout=>2700);

   return(1);
}




sub otipci_OriginLoad
{
   my $self=shift;
   my @param=@_;

   my %loadParam=(
      reset=>0,
      full=>0
   );

   if ($#param==-1){
      @param=(
         "otipci::all",
         "otipci::relation"
      );
   }

   my $reset=0;
   if (lc($param[0]) eq "reset"){
      shift(@param);
      $loadParam{reset}=1;
   }
   if (lc($param[0]) eq "full"){
      shift(@param);
      $loadParam{full}=1;
   }

   foreach my $objname (@param){
      msg(INFO,"start loading $objname");
      my $o=getModuleObject($self->Config,$objname);
      if (!defined($o)){
         my $exitmsg=msg(ERROR,"unamble to create $objname");
         return({exitcode=>1,exitmsg=>$exitmsg});
      }
      if (!$o->can("ORIGIN_Load")){
         my $exitmsg=msg(ERROR,"unamble to call ORIGIN_Load on $objname");
         return({exitcode=>1,exitmsg=>$exitmsg});
      }
      my ($res,$emsg)=$o->ORIGIN_Load(\%loadParam);
      if (ref($res) ne "HASH"){
         return({exitcode=>1,exitmsg=>$emsg});
      }
   }


   return({exitcode=>0,exitmsg=>'ok'});
}



1;
