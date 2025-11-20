package TSharePoint::event::HubMasterOrgDomainImport;
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
use kernel::QRule;
@ISA=qw(kernel::Event kernel::QRule);



sub new
{
   my $type=shift;
   my %param=@_;
   my $self=bless($type->SUPER::new(%param),$type);

   return($self);
}


sub HubMasterOrgDomainImport
{
   my $self=shift;
   my $start=NowStamp("en");


   my $c=0;

   my $i=getModuleObject($self->Config,"TSharePoint::SharePointHubMaster");
   return({}) if ($i->isSuspended());

   if (!($i->Ping())){
      my $infoObj=getModuleObject($self->Config,"itil::lnkapplappl");
      if ($infoObj->NotifyInterfaceContacts($i)){
         return({exitcode=>0,exitmsg=>'Interface notified'});
      }
      return({exitcode=>1,exitmsg=>'not all dataobjects available'});
   }


   my $tlnx=getModuleObject($self->Config,"TeamLeanIX::gov");
   return({}) if ($tlnx->isSuspended());

   if (!($tlnx->Ping())){
      my $infoObj=getModuleObject($self->Config,"itil::lnkapplappl");
      if ($infoObj->NotifyInterfaceContacts($tlnx)){
         return({exitcode=>0,exitmsg=>'Interface notified'});
      }
      return({exitcode=>1,exitmsg=>'not all dataobjects available'});
   }


   my $vou=getModuleObject($self->Config,"TS::vou");
   return({}) if ($vou->isSuspended());

   my $orgdomo=getModuleObject($self->Config,"TS::orgdom");
   return({}) if ($orgdomo->isSuspended());

   my $lnkorgdom=getModuleObject($self->Config,"TS::lnkorgdom");
   return({}) if ($lnkorgdom->isSuspended());


   $vou->SetFilter({cistatusid=>"<6"});
   $vou->SetCurrentView(qw( id shortname rorgid ));
   my $v=$vou->getHashIndexed(qw(shortname));


   $orgdomo->SetFilter({cistatusid=>"4"});
   $orgdomo->SetCurrentView(qw( id orgdomid name cistatusid ));
   my $orgdom=$orgdomo->getHashIndexed(qw(orgdomid));



   my $norgdom={};

   my $iname=$i->Self();

   $i->SetFilter({});
   my @hub=$i->getHashList(qw(hubid domainid domain));

   my $hubdom={};
   foreach my $irec (@hub){
      if (!defined($hubdom->{domainid}->{$irec->{domainid}})){
         $hubdom->{domainid}->{$irec->{domainid}}=[];
      }
      push(@{$hubdom->{domainid}->{$irec->{domainid}}},$irec);
      if (!defined($hubdom->{hubid}->{$irec->{hubid}})){
         $hubdom->{hubid}->{$irec->{hubid}}=[];
      }
      push(@{$hubdom->{hubid}->{$irec->{hubid}}},$irec);
   }

   if (0){  # sync orgdom Table
      foreach my $irec (@hub){
         next if (!($irec->{domainid}=~m/^DOM/)); # C is rotz
         next if ($irec->{domainid} eq "");
         my $name=limitlen($irec->{domain},40,1);
         if (length($name)<5){  # Some Domains are to short named
            $name=$irec->{domainid}.": ".$name;
         } 
         my $domrec={
            cistatusid=>'4',
            name=>$name,
            orgdomid=>$irec->{domainid}
         };
         if (!defined($norgdom->{$irec->{domainid}})){
            $norgdom->{$irec->{domainid}}=$domrec;
         }
      }
      my @opList;
      my $res=OpAnalyse(
            sub{  # comperator
               my ($a,$b)=@_;   # a=lnkadditionalci b=aus AM
               my $eq;
               if ($a->{orgdomid}  eq $b->{orgdomid}){
                  $eq=0;
                  # eq=0 = Satz gefunden und es wird ein Update gemacht
                  if ($a->{cistatusid} eq $b->{cistatusid} &&
                      $a->{name} eq $b->{name}){
                     $eq=1;
                     # eq=1 = alles super - kein Update notwendig
                  }
               }
               return($eq);
            },
            sub{  # oprec generator
              my ($mode,$oldrec,$newrec,%p)=@_;
              if ($mode eq "insert" || $mode eq "update"){
                 my $oprec={
                    OP=>$mode,
                    MSG=>"$mode  $newrec->{orgdomid} in W5Base",
                    DATAOBJ=>'TS::orgdom',
                    DATA=>{
                       name      =>$newrec->{name},
                       cistatusid=>$newrec->{cistatusid},
                       orgdomid  =>$newrec->{orgdomid}
                    }
                 };
                 if ($mode eq "update"){
                    $oprec->{IDENTIFYBY}=$oldrec->{id};
                 }
                 return($oprec);
              }
              elsif ($mode eq "delete"){
                  my $id=$oldrec->{id};
                  return(undef) if ($oldrec->{cistatusid}>4);
                  return({OP=>"update",
                          DATA=>{
                             cistatusid=>'6'
                          },
                          MSG=>"delete ip $oldrec->{name} ".
                               "from W5Base",
                          DATAOBJ=>'TS::orgdom',
                          IDENTIFYBY=>$oldrec->{id},
                          });
               }
               return(undef);
            },
            [values(%{$orgdom->{orgdomid}})],[values(%$norgdom)],\@opList
      );
      if (!$res){
         my $opres=ProcessOpList($orgdomo,\@opList);
      }
    
   }



   #######################################################################
   #  -> Loading orgdomains with id->orgdomid mapping
   $orgdomo->ResetFilter();
   $orgdomo->SetFilter({cistatusid=>'4'});
   $orgdomo->SetCurrentView(qw(id orgdomid name cistatusid ));
   my $orgdom=$orgdomo->getHashIndexed(qw(orgdomid));
print STDERR Dumper($orgdom);

   #######################################################################
   #  -> Loading virutal org-units with id->hubid relation
   $vou->ResetFilter();
   $vou->SetFilter({cistatusid=>'4',hubid=>"![EMPTY]"});
   $vou->SetCurrentView(qw(id shortname hubid));
   my $voulst=$vou->getHashIndexed(qw(hubid));
   # print STDERR Dumper($voulst);

   #######################################################################
   #  -> Loading Mapping from ictoid -> hubid (from TeamLeanIX)
   msg(INFO,"start collecting all ictoNumber->hubid relations from TeamLeanIX");
   $tlnx->ResetFilter();
   $tlnx->SetFilter({});
   my @rawtnlxdata=$tlnx->getHashList(qw(id ictoNumber hubid));
   my @tnlxdata;
   foreach my $tlnxrec (@rawtnlxdata){
     push(@tnlxdata,$tlnxrec) if ($tlnxrec->{hubid} ne "");
   }
   # printf STDERR ("tnlxdata:%s\n",Dumper(\@tnlxdata));

   #######################################################################
   # from HubMaster we have aready the mapping hubid->domainid
   # and thereis exact ONE domainid for a hub.

   # printf STDERR ("hubdom:%s\n",Dumper($hubdom));

   my %sMap;
   my %iMap;

   #######################################################################
   # loading current mappings from $lnkorgdom (in w5base) iMap=istMap
   $lnkorgdom->ResetFilter();
   $lnkorgdom->SetFilter({});

   my @lnkod=$lnkorgdom->getHashList(qw(vouid orgdomid id ictoid ictono));
   foreach my $rec (@lnkod){
      my $vouid=$rec->{vouid};
      my $orgdomid=$rec->{orgdomid};
      my $ictono=$rec->{ictono};
      my $ictoid=$rec->{ictoid};
      $iMap{"iMap:".$orgdomid."-".$ictoid."-".$vouid}={
         vouid=>$vouid,
         ictono=>$ictono,
         ictoid=>$ictoid,
         orgdomid=>$orgdomid,
         id=>$rec->{id}
      };
   }
   #######################################################################

#printf STDERR ("sMap:%s\n",Dumper(\%sMap));



   #######################################################################
   # Taget is to build vou(hubid) -> orgdom(domainid) -> ictoid 


#   # create master mapping between vouid (W5BaseID Hub) and orgdomid (W5BaseID OrgDomain)
#   foreach my $irec (@capeData){
#      my ($CapeHubShortname)=$irec->{organisation}=~m/^\S*HUB\S+\s+(\S{3})\s+/;
#      next if ($CapeHubShortname eq "");
#      if (exists($v->{shortname}->{$CapeHubShortname})){
#         my $w5vouid=$v->{shortname}->{$CapeHubShortname}->{id};
#         my $orgdomainShortName=$irec->{orgdomainid};
#         if (exists($orgdom->{orgdomid}->{$orgdomainShortName})){
#            my $w5orgdomid=$orgdom->{orgdomid}->{$orgdomainShortName}->{id};
#            #printf STDERR ("archapplid=%s orgdomainShortName=%s hubshort=%s w5vouid=%s w5orgdomid=%s\n",
#            #          $irec->{archapplid},$orgdomainShortName,$CapeHubShortname,$w5vouid,$w5orgdomid);   
#            my $ictono=$irec->{id};
#            my $ictoid=$irec->{archapplid};
#            $sMap{"sMap:".$w5orgdomid."-".$ictono."-".$w5vouid}={
#               vouid=>$w5vouid,
#               ictono=>$ictoid,
#               ictoid=>$ictono,
#               orgdomid=>$w5orgdomid
#            };
#         }
#      }
#      else{
#        # msg(ERROR,"unknown HUP shortname from ".$irec->{archapplid}."/".$CapeHubShortname);
#      }
#   }

exit(1);








#
#   if (1){
#      my @opList;
#      my $res=OpAnalyse(
#            sub{  # comperator
#               my ($a,$b)=@_;   # a=lnkadditionalci b=aus AM
#               my $eq;
#               if ($a->{vouid}  eq $b->{vouid} &&
#                   $a->{orgdomid}  eq $b->{orgdomid} &&
#                   $a->{ictoid}  eq $b->{ictoid} ){
#                  $eq=1;
#               }
#               return($eq);
#            },
#            sub{  # oprec generator
#              my ($mode,$oldrec,$newrec,%p)=@_;
#              if ($mode eq "insert" || $mode eq "update"){
#                 my $oprec={
#                    OP=>$mode,
#                    DATAOBJ=>'TS::lnkorgdom',
#                    DATA=>{
#                       vouid     =>$newrec->{vouid},
#                       orgdomid  =>$newrec->{orgdomid},
#                       ictoid    =>$newrec->{ictoid},
#                       ictono    =>$newrec->{ictono}
#                    }
#                 };
#                 return($oprec);
#              }
#              elsif ($mode eq "delete"){
#                 my $oprec={
#                    OP=>$mode,
#                    DATAOBJ=>'TS::lnkorgdom',
#                    IDENTIFYBY=>$oldrec->{id}
#                 };
#                 return($oprec);
#              }
#              return(undef);
#            },
#            [values(%iMap)],[values(%sMap)],\@opList
#      );
#      if (!$res){
#         my $opres=ProcessOpList($orgdomo,\@opList);
#      }
#   }
   return({exitcode=>0});
}


1;
