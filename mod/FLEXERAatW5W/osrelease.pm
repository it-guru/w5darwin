package FLEXERAatW5W::osrelease;
#  W5Base Framework
#  Copyright (C) 2017  Hartmut Vogler (it@guru.de)
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
use FLEXERAatW5W::lib::Listedit;
use kernel::Field;
@ISA=qw(FLEXERAatW5W::lib::Listedit);

sub new
{
   my $type=shift;
   my %param=@_;
   $param{MainSearchFieldLines}=4;
   my $self=bless($type->SUPER::new(%param),$type);
   $self->{use_distinct}=1;

   
   $self->AddFields(
      new kernel::Field::Text(
                name          =>'osrelease',
                label         =>'OS-Release',
                ignorecase    =>1,
                dataobjattr   =>'SYSTEMOS'),

      new kernel::Field::Text(
                name          =>'w5osrelease',
                label         =>'W5Mapped OS-Release',
                searchable    =>0,
                onRawValue    =>\&matchW5Base),
   );
   $self->setWorktable("FLEXERA_system");
   $self->setDefaultView(qw(osrelease w5osrelease));
   return($self);
}


sub matchW5Base
{
   my $self=shift;
   my $current=shift;
   my $mappedos=$current->{osrelease};
   my $app=$self->getParent();

   my $w5os=$app->getPersistentModuleObject("itil::osrelease");

   my $iomappedRec={};
   my $d;
   my @targetid=$w5os->getIdByHashIOMapped(
      "FLEXERAatW5::system",
      {name=>$mappedos},
      DEBUG=>\$d,
      iomapped=>$iomappedRec,
      ForceLikeSearch=>1
   );
   if ($#targetid==-1){
      @targetid=$w5os->getIdByHashIOMapped(
         "FLEXERAatW5::system",
         {name=>trim($mappedos)." 64Bit"},
         DEBUG=>\$d,
         iomapped=>$iomappedRec,
         ForceLikeSearch=>1
      );
   }
   if ($#targetid==0){
      return($iomappedRec->{name})
   }
   return(undef);
}


sub Initialize
{
   my $self=shift;

   my @result=$self->AddDatabase(DB=>new kernel::database($self,"w5warehouse"));
   return(@result) if (defined($result[0]) && $result[0] eq "InitERROR");
   return(1) if (defined($self->{DB}));
   return(0);
}

sub initSqlWhere
{
   my $self=shift;
   my $mode=shift;
   my $where="";
   if ($mode eq "select"){
      $where="((FLEXERA_system.devicestatus='ACTIVE') and FLEXERA_system.SYSTEMOS is not null)";
   }
   return($where);
}



sub initSearchQuery
{
   my $self=shift;
   if (!defined(Query->Param("search_systemdevicestatus"))){
     Query->Param("search_systemdevicestatus"=>"ACTIVE");
   }
}




sub getRecordImageUrl
{
   my $self=shift;
   my $cgi=new CGI({HTTP_ACCEPT_LANGUAGE=>$ENV{HTTP_ACCEPT_LANGUAGE}});
   return("../../../public/itil/load/system.jpg?".$cgi->query_string());
}



sub checkIfVM
{
   my $self=shift;
   my $mode=shift;
   my %param=@_;
   my $current=$param{current};

   return(0) if (!defined($current));
   return(1) if ($current->{is_vm});
   return(0);
}






sub isViewValid
{
   my $self=shift;
   my $rec=shift;
   return("ALL");
}


sub isWriteValid
{
   my $self=shift;
   my $rec=shift;
   return(undef);
}



sub getSqlFrom
{
   my $self=shift;
   my $mode=shift;
   my @flt=@_;
   my ($worktable,$workdb)=$self->getWorktable();
   my $from="";

   $from.="$worktable  ".
          "left outer join (".
             "select distinct FLEXERADEVICEID,W5BASEID ".
             "from FLEXERA_system2w5system) UFLEXERA_system2w5system ".
          "on $worktable.FLEXERASYSTEMID=".
          "UFLEXERA_system2w5system.FLEXERADEVICEID ";

   return($from);
}




sub getDetailBlockPriority
{
   my $self=shift;
   return(qw(header default software vm w5basedata source));
}  



sub extractAutoDiscData      # SetFilter Call ist Job des Aufrufers
{
   my $self=shift;
   my @res=();

   $self->SetCurrentView(qw(systemname systemid osrelease instpkgsoftware));

   my ($rec,$msg)=$self->getFirst();
   if (defined($rec)){
      do{

         #####################################################################
         my %e=(
            section=>'SYSTEMNAME',
            scanname=>$rec->{systemname}, 
            quality=>-50,    # relativ schlecht verlässlich
            processable=>1,
            forcesysteminst=>1  # MUSS System zugeordnet sein
         );
         push(@res,\%e);
         #####################################################################

         #####################################################################

         my $chkobj=getModuleObject($self->Config,"itil::osrelease");
         my $mappedos=$rec->{osrelease};
         my $iomappedRec={};
         my $d;
         my @targetid=$chkobj->getIdByHashIOMapped(
            "FLEXERAatW5::system",
            {name=>$rec->{osrelease}},
            DEBUG=>\$d,
            iomapped=>$iomappedRec,
            ForceLikeSearch=>1 
         );
         if ($#targetid==0){
            my %e=(
               section=>'OSRELEASE',
               scanname=>$iomappedRec->{name}, 
               scanextra1=>$rec->{osrelease}, 
               quality=>-10,    # relativ schlecht verlässlich
               processable=>1,
               forcesysteminst=>1  # MUSS System zugeordnet sein
            );
            push(@res,\%e);
         }
         #####################################################################


         foreach my $s (@{$rec->{instpkgsoftware}}){
            # at this point, there can be nativ scandata be patched to correct
            # scan informations!  
            my $version=$s->{fullversion};
            $version=~s/-.*$//;  # remove package version
            my %e=(
               section=>'SOFTWARE',
               scanname=>$s->{software},
               scanextra2=>$version,
               quality=>2,    # schlechter als AM
               processable=>1,
               backendload=>$s->{scandate},
               autodischint=>$self->Self.": ".$rec->{id}.
                             ": ".$rec->{systemid}.
                             ": ".$rec->{name}.":SOFTWARE :".$s->{id}.": ".
                             $s->{software}
            );
            # Flexera Agent ist immer Hostbasiert installiert.
            if ($s->{software}=~m/^FlexNet Inventory Agent/i){
               $e{forcesysteminst}=1;
               $e{allowautoremove}=1;
               $e{quality}=100;  #flexera weiss am besten über flexera bescheid
            }
            push(@res,\%e);
         }
#         foreach my $s (@{$rec->{ipaddresses}}){
#            my %e=(
#               section=>'IPADDR',
#               scanname=>$s->{address},
#               scanextra2=>$s->{physicaladdress},
#               quality=>10,    # relativ verlässlich
#               processable=>0  # nicht verwendbar - da AM Master!
#            );
#            push(@res,\%e);
#         }
         ($rec,$msg)=$self->getNext();
      } until(!defined($rec));
   }
   return(@res);
}


1;
