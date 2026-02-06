package TeamLeanIX::event::TeamICTOimport;
#  W5Base Framework
#  Copyright (C) 2025  Hartmut Vogler (it@guru.de)
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

   $self->{fieldlist}=[qw(ictono)];

   return($self);
}


sub TeamICTOimport
{
   my $self=shift;

   my $appl=getModuleObject($self->Config,"TS::appl");
   return({}) if ($appl->isSuspended());
   $appl->SetFilter({cistatusid=>['3','4']});
   my $oldictono;
   my %icto=();
   my $start=NowStamp("en");
   msg(INFO,"start reading icto-id list");
   foreach my $arec ($appl->getHashList(@{$self->{fieldlist}},"id")){
      if ($arec->{ictono} ne ""){
         my $i=lc($arec->{ictono});
         $icto{$i}=[] if (!exists($icto{$i}));
         push(@{$icto{$i}},$arec->{id});
      }
      $oldictono=$arec->{ictono};
   }
#   if (1){  # reduce data for debugging
#      foreach my $i (keys(%icto)){
#         if (!in_array([$i],[qw(icto-4340 icto-4488
#                                icto-13741 icto-17962)])){
#            delete($icto{$i});
#         }
#      }
#   }
   my $nicto=keys(%icto);
   msg(INFO,"found  $nicto ictos in it-inventory");
   my $agrp=getModuleObject($self->Config,"itil::applgrp");
   if ($agrp->isSuspended()){
      return({exitcode=>'100',exitmsg=>'suspended itil::applgrp'});
   }
   my $m=getModuleObject($self->Config,"base::mandator");
   if ($m->isSuspended()){
      return({exitcode=>'100',exitmsg=>'suspended base::mandator'});
   }
   my $grp=getModuleObject($self->Config,"base::grp");
   if ($grp->isSuspended()){
      return({exitcode=>'100',exitmsg=>'suspended base::grp'});
   }
   my $i=getModuleObject($self->Config,"TeamLeanIX::gov");
   if ($i->isSuspended()){
      return({exitcode=>'100',exitmsg=>'suspended TeamLeanIX::gov'});
   }

   if (!($i->Ping())){
      my $infoObj=getModuleObject($self->Config,"itil::lnkapplappl");
      if ($infoObj->NotifyInterfaceContacts($i)){
         return({exitcode=>0,exitmsg=>'Interface notified'});
      }
      return({exitcode=>1,exitmsg=>'not all dataobjects available'});
   }

   my $la=getModuleObject($self->Config,"itil::lnkapplgrpappl");



   my $iname=$i->Self();
   my $c=0;

   my @l;
   foreach my $ictoid (keys(%icto)){
      $i->ResetFilter();
      $i->SetFilter({ictoNumber=>$ictoid});
      my ($remoterec)=$i->getOnlyFirst(qw(ictoNumber fullname description
                                          shortname status 
                                          organisation 
                                          orgareaid));
      if (defined($remoterec)){
         my $orgareaid=$remoterec->{orgareaid}; # ensure orgareaid is resolved
         push(@l,$remoterec);
      }
      else{
        msg(INFO,"can not resolv $ictoid by $iname");
      }
   }

   foreach my $irec (@l){
      $c++;
      my $mandator="TelekomIT";
      $m->ResetFilter();
      $m->SetFilter({name=>\$mandator,cistatusid=>\'4'});
      my ($mandatorid)=$m->getVal("grpid");
      my $shortname=$irec->{shortname};

      $shortname="NONAME ".$irec->{ictoNumber} if ($shortname eq "");
      $shortname=~s/[^a-z0-9:-]/_/gi;

      $agrp->ResetFilter();
      $agrp->SetFilter({name=>$shortname,applgrpid=>"!".$irec->{ictoNumber}});
      my ($agrpid)=$agrp->getVal("id");
      if ($agrpid ne ""){  # make it unique
         $shortname.="_".$irec->{ictoNumber};
      }

      my $cistatusid;
      if ($irec->{status} eq "Active"){
         $cistatusid="4";
      }
      if ($irec->{status} eq "Plan"){
         $cistatusid="3";
      }
      if ($irec->{status} eq "PhaseIn"){
         $cistatusid="3";
      }
      if ($irec->{status} eq "EndOfLife"){
         $cistatusid="6";
      }
      if ($irec->{status} eq "PhaseOut"){
         $cistatusid="6";
      }
      if ($irec->{status} eq "Retired"){
         $cistatusid="6";
      }
      if (!defined($cistatusid)){
         msg(WARN,"skip irec: ictoNumber='$irec->{ictoNumber}' ".
                             "status='$irec->{status}' id='$agrpid'");
         next;
      }

      my $responseorgid=$irec->{orgareaid};

      my $debug;
#      my %lrec=(fullname=>$irec->{organisation});
#      if ($irec->{organisation} ne ""){
#         my $grpid=$grp->getIdByHashIOMapped("TeamLeanIX::archappl",\%lrec,
#                                                 DEBUG=>\$debug);
#         $responseorgid=$grpid;
#      }

      my $newrec={
            cistatusid=>$cistatusid,
            name=>$shortname,
            fullname=>$irec->{fullname},
            applgrpid=>$irec->{ictoNumber},
            comments=>$irec->{description},
            mandatorid=>$mandatorid,
            responseorgid=>$responseorgid,
            srcid=>$irec->{ictoNumber},
            srcsys=>$iname,
            srcload=>$start
      };

      if ($cistatusid>5){
         $agrp->ResetFilter();
         $agrp->SetFilter({srcsys=>\$iname,srcid=>\$irec->{ictoNumber}});
         my ($chkrec)=$agrp->getOnlyFirst(qw(id));
         if (defined($chkrec)){  # record exists - and we will only do an update
            delete($newrec->{name}); # update of name makes no sense, if rec is del
         }
      }

      my @idl=$agrp->ValidatedInsertOrUpdateRecord($newrec,
         {srcid=>\$irec->{ictoNumber}}
      );
      if ($#idl==0){
         foreach my $applid (@{$icto{lc($irec->{ictoNumber})}}){
            my $lid=lc($irec->{ictoNumber})."-".$applid;
            my @l=$la->ValidatedInsertOrUpdateRecord({
                  applgrpid=>$idl[0],
                  applid=>$applid,
                  srcid=>$lid,
                  srcsys=>$iname,
                  srcload=>$start
               },
               {srcsys=>"$iname tscape::archappl",applid=>\$applid}
            );
         }
      }
      else{
         printf STDERR ("update problem: %s\n",Dumper($newrec));
         exit(1);
      }
   }
   if ($c<10){
      return({exitcode=>1,
              exitmsg=>'skipped cleanup due to few import records'});
   }
   else{
      $agrp->ResetFilter();
      $agrp->SetFilter({'srcload'=>"<\"$start\"",srcsys=>\$iname});
      $agrp->SetCurrentView(qw(ALL));
      my $opagrp=$agrp->Clone();

      my ($arec,$msg)=$agrp->getFirst(unbuffered=>1);
      if (defined($arec)){
         do{
            $opagrp->ValidatedUpdateRecord($arec,{cistatusid=>6},{
               id=>\$arec->{id}
            });
            ($arec,$msg)=$agrp->getNext();
         }until(!defined($arec));
      }
      $la->BulkDeleteRecord({'srcload'=>"<\"$start\"",srcsys=>\$iname});
   }
   return({exitcode=>0});
}


1;
