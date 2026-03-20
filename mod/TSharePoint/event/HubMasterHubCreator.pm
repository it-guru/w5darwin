package TSharePoint::event::HubMasterHubCreator;
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
use kernel::QRule;
@ISA=qw(kernel::Event kernel::QRule);



sub new
{
   my $type=shift;
   my %param=@_;
   my $self=bless($type->SUPER::new(%param),$type);

   return($self);
}


sub HubMasterHubCreator
{
   my $self=shift;
   my @param=@_;
   my $start=NowStamp("en");


   my $c=0;

   my $hubm=getModuleObject($self->Config,"TSharePoint::SharePointHubMaster");
   return({}) if ($hubm->isSuspended());

   my $vou=getModuleObject($self->Config,"TS::vou");
   return({}) if ($vou->isSuspended());

   my $user=getModuleObject($self->Config,"base::user");

   my $grp=getModuleObject($self->Config,"base::grp");


   if (!($hubm->Ping()) || !($vou->Ping())){
      my $infoObj=getModuleObject($self->Config,"itil::lnkapplappl");
      if ($infoObj->NotifyInterfaceContacts($hubm)){
         return({exitcode=>0,exitmsg=>'Interface notified'});
      }
      return({exitcode=>1,exitmsg=>'not all dataobjects available'});
   }


   $vou->SetFilter({});
   $vou->SetCurrentView(qw( id shortname hubid ));
   my $v=$vou->getHashIndexed(qw(shortname hubid));

   $hubm->SetFilter({status=>'AKTIV'});
   $hubm->SetCurrentView(qw( id shortname name hubid sdcid boit_email));
   my $h=$hubm->getHashIndexed(qw(shortname hubid));


   $grp->SetFilter({cistatusid=>'4',is_org=>1,fullname=>"*.DTIT"});
   $grp->SetCurrentView(qw( grpid fullname name ));
   my $orggrp=$grp->getHashIndexed(qw(grpid fullname));

   my $rorgid;

   if (!exists($orggrp->{fullname}->{'EC.DTIT'})){
      msg(ERROR,"can not identify group EC.DTIT");
      return({exitcode=>1});
   }
   else{
      $rorgid=$orggrp->{fullname}->{'EC.DTIT'}->{grpid};
   }


   # find missing hubid's
   my $c=0;
   foreach my $hubid (sort(keys(%{$h->{hubid}}))){
      next if ($hubid eq "HUB-PZZ"); # is a dummy hub

      if (!exists($v->{hubid}->{$hubid})){
         my $boidemail=$h->{hubid}->{$hubid}->{boit_email};
         next if ($boidemail eq "");
        
         my $boituserid;
         $user->ResetFilter();
         $user->SetFilter({email=>$boidemail,cistatusid=>\'4',usertyp=>\'user'});
         my @ul=$user->getHashList(qw(userid fullname email));
         if ($#ul==0){
            $boituserid=$ul[0]->{userid};
         }
        
         if ($boituserid eq "" && in_array(\@param,"all")){
            msg(WARN,"load new external user for BOIT $boidemail");
            $boituserid=$user->GetW5BaseUserID($boidemail,"email");
         }
         if ($boituserid eq ""){
            next;
         }
     
         $user->ResetFilter();
         $user->SetFilter({userid=>\$boituserid});
         my @ul=$user->getHashList(qw(ALL));
         if ($#ul!=0){
            msg(ERROR,"can not load userid $boituserid record for ".$boidemail);
            next;
         }
         my $boit=$ul[0];
        
         my $op=$vou->Clone();


         $c++;
         msg(INFO,"missing hubid '$hubid' no=$c");
         my $newid=$op->ValidatedInsertRecord({
            cistatusid=>4,
            databossid=>$boit->{userid},
            leaderitid=>$boit->{userid},
            shortname=>$h->{hubid}->{$hubid}->{shortname},
            sdcid=>$h->{hubid}->{$hubid}->{sdcid},
            hubid=>$hubid,
            rorgid=>$rorgid,
            responsibleorg=>$orggrp->{grpid}->{$rorgid}->{fullname},
            outype=>"HUB",
            name=>$h->{hubid}->{$hubid}->{name} 
         });
         $op->ResetFilter();
         $op->SetFilter({id=>\$newid});
         my @n=$op->getHashList(qw(ALL));
         foreach my $rec (@n){
            msg(INFO,"HubMasterHubCreator create :".$rec->{shortname});
            my %notifyparam=(emailbcc=>['11634953080001']);
            my %notifycontrol=();
            $notifycontrol{mode}="INFO";
            $op->NotifyWriteAuthorizedContacts($rec,undef,
                                              \%notifyparam,\%notifycontrol,sub{
               my ($subject,$ntext);
               my $subject=$self->T("virutal oranisation unit (HUB) created").
                           ": ".$rec->{shortname};
               my $tmpl=$op->getParsedTemplate("tmpl/HubMasterHubCreator_new",{
                  static=>{
                     SHORTNAME=>$rec->{shortname},
                     URL=>$rec->{urlofcurrentrec}
                  }
               });
               return($subject,$tmpl);
            });


         }

         #print STDERR Dumper(\@n);
      }
   }


#   print STDERR Dumper($v);
#   print STDERR Dumper($h);


   return({exitcode=>0});
}


1;
