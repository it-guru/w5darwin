package tsacinv::housingsystem;
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
use kernel::App::Web;
use kernel::DataObj::DB;
use kernel::Field;
use tsacinv::lib::tools;
use tsacinv::costcenter;

@ISA=qw(kernel::App::Web::Listedit kernel::DataObj::DB tsacinv::lib::tools);

sub new
{
   my $type=shift;
   my %param=@_;
   $param{MainSearchFieldLines}=4;
   my $self=bless($type->SUPER::new(%param),$type);

   
   $self->AddFields(
      new kernel::Field::Linenumber(
                name          =>'linenumber',
                label         =>'No.'),

      new kernel::Field::Text(
                name          =>'fullname',
                label         =>'full CI-Name',
                searchable    =>0,
                htmldetail    =>0,
                dataobjattr   =>'system."fullname"'),

      new kernel::Field::Text(
                name          =>'systemname',
                label         =>'Systemname',
                uppersearch   =>1,
                size          =>'16',
                dataobjattr   =>'"systemname"'),

      new kernel::Field::Id(
                name          =>'systemid',
                label         =>'SystemId',
                size          =>'13',
                explore       =>100,
                searchable    =>1,
                uppersearch   =>1,
                align         =>'left',
                dataobjattr   =>'system."systemid"'),

      new kernel::Field::RecordUrl(),


      new kernel::Field::Text(
                name          =>'status',
                label         =>'Status',
                dataobjattr   =>'system."status"'),

      new kernel::Field::Text(
                name          =>'housingassetid',
                label         =>'housing AssetID',
                dataobjattr   =>'asset."assetid"'),

      new kernel::Field::Boolean(
                name          =>'deleted',
                readonly      =>1,
                label         =>'marked as delete',
                dataobjattr   =>'system."deleted"'),

      new kernel::Field::Text(
                name          =>'conumber',
                label         =>'CO-Number',
                searchable    =>0,
                size          =>'15',
                dataobjattr   =>'system."conumber"'),

      new kernel::Field::Text(
                name          =>'customerlink',
                label         =>'Customer (link)',
                searchable    =>0,
                dataobjattr   =>'system."customerlink"'),


      new kernel::Field::Text(
                name          =>'invoiceusage',
                label         =>'invoice considered Usage',
                dataobjattr   =>"
                   (case 
                     when (system.\"usage\" like 'HOUSING' or 
                           system.\"usage\" like 'OSY-I: HOUSING' ) and
                          system.\"srcsys\" is null and
                          system.\"srcid\" is null and
                          system.\"systemola\" like '%-ONLY' and 
                          system.\"systemname\" like '%_HW' and 
                          (cfmassignment.\"name\"='MIS' or 
                           cfmassignment.\"name\" like 'MIS.%') and
                          (inmassignment.\"name\"='TI' or 
                           inmassignment.\"name\" like 'TI.%' or
                           inmassignment.\"name\"='DT' or 
                           inmassignment.\"name\" like 'DT.%' or
                           inmassignment.\"name\"='TIT' or 
                           inmassignment.\"name\" like 'TIT.%') 
                          then n'INVOICE_ONLY'
                     when (system.\"usage\" like 'HOUSING' or
                           system.\"usage\" like 'OSY-I: HOUSING' ) and
                          system.\"srcsys\" is null and
                          system.\"srcid\" is null and
                          system.\"systemola\" like '%-ONLY' and 
                          (cfmassignment.\"name\"='MIS' or 
                           cfmassignment.\"name\" like 'MIS.%') and
                          (inmassignment.\"name\"='TI' or 
                           inmassignment.\"name\" like 'TI.%' or
                           inmassignment.\"name\"='DT' or 
                           inmassignment.\"name\" like 'DT.%' or
                           inmassignment.\"name\"='TIT' or 
                           inmassignment.\"name\" like 'TIT.%') 
                          then n'INVOICE_ONLY?'
                     else system.\"usage\"
                    end)
                "),

      new kernel::Field::Text(
                name          =>'rawusage',
                label         =>'Usage',
                dataobjattr   =>"system.\"usage\""),

      new kernel::Field::Link(
                name          =>'lassetid',
                label         =>'AC-AssetID',
                selectfix     =>1,
                dataobjattr   =>'system."lassetid"'),

      new kernel::Field::Text(
                name          =>'systemids',
                vjointo       =>\'tsacinv::system',
                vjoinon       =>['lassetid'=>'lassetid'],
                vjoinbase     =>[{status=>"\"!out of operation\"",
                                  deleted=>\'0'}],
                weblinkto     =>'none',
                vjoindisp     =>'systemid',
                group         =>'systems',
                label         =>'all SystemIDs on Asset'),

      new kernel::Field::SubList(
                name          =>'applications',
                label         =>'Applications',
                group         =>'applications',
                vjointo       =>'tsacinv::lnkapplsystem',
                vjoinbase     =>{deleted=>'0'},
                vjoinon       =>['realsystemids'=>'systemid'],
                vjoindisp     =>[qw(parent applid)],
                vjoininhash   =>['parent','applid','usage','comments']),

      new kernel::Field::Text(
                name          =>'realsystemids',
                searchable    =>0,
                label         =>'real System-SystemIDs',
                onRawValue    =>\&CalcRealSystemIDs,
                depend        =>['systemids','systemid']),


      new kernel::Field::Date(
                name          =>'cdate',
                group         =>'source',
                label         =>'Creation-Date',
                dataobjattr   =>'system."cdate"'),

      new kernel::Field::Date(
                name          =>'mdate',
                group         =>'source',
                label         =>'Modification-Date',
                dataobjattr   =>'system."mdate"'),

#      new kernel::Field::Date(
#                name          =>'lastqcheck',
#                group         =>'source',
#                label         =>'Quality Check last date',
#                dataobjattr   =>'amportfolio.dqualitycheck'),

      new kernel::Field::Date(
                name          =>'mdaterev',
                group         =>'source',
                uivisible     =>0,
                sqlorder      =>'desc',
                label         =>'Modification-Date reverse',
                dataobjattr   =>'system."mdaterev"'),

      new kernel::Field::Text(
                name          =>'srcsys',
                group         =>'source',
                label         =>'Source-System',
                dataobjattr   =>'system."srcsys"'),

      new kernel::Field::Text(                 
                name          =>'srcid',       
                group         =>'source',
                label         =>'Source-Id',
                dataobjattr   =>'system."srcid"'),

   );
   $self->{use_distinct}=0;
   $self->setWorktable("system");


   $self->setDefaultView(qw(systemname status systemid  conumber customerlink
                            invoiceusage rawusage housingassetid
                            systemids realsystemids applications));
   return($self);
}


sub Initialize
{
   my $self=shift;

   my @result=$self->AddDatabase(DB=>new kernel::database($self,"tsac"));
   return(@result) if (defined($result[0]) && $result[0] eq "InitERROR");
   $self->amInitializeOraSession();
   return(1) if (defined($self->{DB}));
   return(0);
}


sub CalcRealSystemIDs
{
   my $self=shift;
   my $current=shift;
   my $systemid=$current->{systemid};
   my $app=$self->getParent();
   my $c=$self->getParent->Context();

   my $fo=$app->getField("systemids",$current);
   my $systemids=$fo->RawValue($current);

   if (ref($systemids) ne "ARRAY"){
      $systemids=[$systemids];
   }
   my @systemids=@{$systemids};
   if ($#systemids!=0){
      @systemids=grep(!/^$systemid$/,@systemids)
   }
   print STDERR Dumper($current->{systemids});

   return(\@systemids);
}



sub getSqlFrom
{
   my $self=shift;

   my $from="system ".
            "left outer join grp inmassignment ".
            "on system.\"lincidentagid\"=inmassignment.\"lgroupid\" ".
            "left outer join grp cfmassignment ".
            "on system.\"lassignmentid\"=cfmassignment.\"lgroupid\" ".
            "left outer join asset on system.\"lassetid\"=asset.\"lassetid\"";
   return($from);
}


sub initSqlWhere
{
   my $self=shift;
   my $where="(system.\"usage\"='HOUSING'  or ".
             " system.\"usage\"='OSY-I: HOUSING')";
   return($where);
}




sub initSearchQuery
{
   my $self=shift;
   if (!defined(Query->Param("search_status"))){
     Query->Param("search_status"=>"\"!out of operation\"");
   }
   if (!defined(Query->Param("search_deleted"))){
     Query->Param("search_deleted"=>$self->T("no"));
   }
   if (!defined(Query->Param("search_invoiceusage"))){
     Query->Param("search_invoiceusage"=>"INVOICE_ONLY?")
   }
}

sub getFieldObjsByView
{
   my $self=shift;
   my $view=shift;
   my %param=@_;

   my @l=$self->SUPER::getFieldObjsByView($view,%param);

   #
   # hack to prevent display of "norsolutionclass" in outputs other then
   # Standard-Detail
   #
   if (defined($param{current}) && exists($param{current}->{norsolutionclass})){
      if ($param{output} ne "kernel::Output::HtmlDetail"){
         if (!$self->IsMemberOf("admin") &&
             !$self->IsMemberOf("w5base.tsacinv.system.securityread")){
            @l=grep({$_->{name} ne "norsolutionclass"} @l);
         }
      }
   }
   return(@l);
}



sub SetFilter
{
   my $self=shift;
   my @flt=@_;

   if ($W5V2::OperationContext eq "W5Replicate"){
      if ($#flt!=0 || ref($flt[0]) ne "HASH"){
         $self->LastMsg("ERROR","invalid Filter request on $self");
         return(undef);
      }
      if ((!exists($flt[0]->{systemid})) ||
          !ref($flt[0]->{systemid})){   # exakt record references are not
         my %f1=(%{$flt[0]});           # time filtered
         $f1{status}='!"out of operation"';

         my %f2=(%{$flt[0]});
         $f2{status}='"out of operation"';
         $f2{mdate}='>now-7d';

         @flt=([\%f1,\%f2]);
      }
   }
   #print STDERR Dumper(\@flt);
   #Stacktrace(1);
   #sleep(10);
   return($self->SUPER::SetFilter(@flt));
}






sub getRecordImageUrl
{
   my $self=shift;
   my $cgi=new CGI({HTTP_ACCEPT_LANGUAGE=>$ENV{HTTP_ACCEPT_LANGUAGE}});
   return("../../../public/itil/load/system.jpg?".$cgi->query_string());
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


sub getDetailBlockPriority
{
   my $self=shift;
   return(qw(header default location applications ipaddresses software 
             usedsharedcomp
             orderedservices services backups 
             assetdata assetfinanz saphier acmdb
             w5basedata source));
}  



sub isQualityCheckValid
{
   my $self=shift;
   my $rec=shift;
   return(0);
}










1;
