package PSI::system;
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
use kernel::Field;
use kernel::App::Web::Listedit;
use kernel::DataObj::ElasticSearch;
use PSI::lib::Listedit;
use JSON;
use MIME::Base64;
@ISA=qw(kernel::App::Web::Listedit kernel::DataObj::ElasticSearch 
        PSI::lib::Listedit);


sub new
{
   my $type=shift;
   my %param=@_;
   my $self=bless($type->SUPER::new(%param),$type);

   $self->AddFields(
      new kernel::Field::Id(     
            name          =>'id',
            searchable    =>0,
            group         =>'source',
            dataobjattr   =>'_id',
            label         =>'Id'),

      new kernel::Field::RecordUrl(),

      new kernel::Field::Text(     
            name          =>'name',
            dataobjattr   =>'_source.name',
            label         =>'Name'),

      new kernel::Field::Text(     
            name          =>'fullname',
            dataobjattr   =>'_source.fullname',
            htmlDetail    =>0,
            searchable    =>0,
            label         =>'Fullname'),

      new kernel::Field::Text(     
            name          =>'fullname',
            dataobjattr   =>'_source.fullname',
            htmlDetail    =>0,
            searchable    =>0,
            label         =>''),

      new kernel::Field::Text(     
            name          =>'systemNumber',
            dataobjattr   =>'_source.systemNumber',
            label         =>'systemNumber'),

      new kernel::Field::Text(     
            name          =>'status',
            dataobjattr   =>'_source.operationStatus.status',
            label         =>'Status'),

      new kernel::Field::Date(     
            name          =>'startDate',
            dataobjattr   =>'_source.operationStatus.startDate',
            htmldetail    =>'NotEmpty',
            searchable    =>0,
            label         =>'startDate'),

      new kernel::Field::Date(     
            name          =>'endDate',
            dataobjattr   =>'_source.operationStatus.endDate',
            htmldetail    =>'NotEmpty',
            searchable    =>0,
            label         =>'endDate'),

      new kernel::Field::Date(     
            name          =>'dtLastLoad',
            dataobjattr   =>'_source.dtLastLoad',
            group         =>'source',
            searchable    =>0,
            label         =>'dtLastLoad'),

      new kernel::Field::Text(     
            name          =>'ownerOrganizationTsisOrgUnitId',
            dataobjattr   =>'_source.ownerOrganizationTsisOrgUnitId',
            group         =>'source',
            searchable    =>0,
            label         =>'ownerOrganizationTsisOrgUnitId'),

      new kernel::Field::Email(     
            name          =>'technicalSystemOwnerEmail',
            dataobjattr   =>'_source.technicalSystemOwner.email',
            label         =>'technicalSystemOwner'),

      new kernel::Field::Email(     
            name          =>'functionalSystemOwner',
            dataobjattr   =>'_source.functionalSystemOwner.email',
            label         =>'functionalSystemOwner'),

      new kernel::Field::Textarea(     
            name          =>'businessProcess',
            dataobjattr   =>'_source.businessProcess',
            searchable    =>0,
            label         =>'businessProcess'),

      new kernel::Field::Date(     
            name          =>'dtLastLoad',
            dataobjattr   =>'_source.dtLastLoad',
            group         =>'source',
            searchable    =>0,
            label         =>'dtLastLoad'),

#      new kernel::Field::Text(
#            name          =>'srcid',
#            group         =>'source',
#            label         =>'Source-Id',
#            dataobjattr   =>'_source.uuid'),

   );
   $self->setDefaultView(qw(id fullname status ));
   $self->LimitBackend(10000);
   return($self);
}


sub getCredentialName
{
   my $self=shift;

   return("PSI");
}



sub ORIGIN_Load
{
   my $self=shift;
   my $loadParam=shift;

   my $credentialName="ORIGIN_".$self->getCredentialName();
   my $indexname=$self->ESindexName();
   my $opNowStamp=NowStamp("ISO");

   my ($res,$emsg)=$self->ESrestETLload({
        settings=>{
           number_of_shards=>1,
           number_of_replicas=>1,
           analysis=>{
              normalizer=> {
                lowercase_normalizer=> {
                  type=>"custom",
                  filter=>["lowercase"]
                }
              }
           }
        },
        mappings=>{
           _meta=>{
              version=>21
           },
           properties=>{
              uuid    =>{type=>'text',
                         fields=> {
                             keyword=> {
                               type=> "keyword",
                               ignore_above=> 256
                             }
                           }
                         },
           systemNumber=>{type=>'text',
                         fields=> {
                             keyword=> {
                               type=> "keyword",
                               ignore_above=> 256
                             }
                           }
                         },
              name    =>{type=>'text',
                         fields=> {
                             keyword=> {
                               type=> "keyword",
                               ignore_above=> 256
                             }
                           }
                         }
           }
        }
      },sub {
         my ($session,$meta)=@_;

         my $idgt=".";
         my $limit=1000;
         my $ESjqTransform=
            "try( ".
            "fromjson | ".
            "if (.systems | type!=\"array\" or length == 0) ".
            "then error(\"unexpected input - no array\") ".
            "else  .systems[] ".
            "| { index: { _id: .uuid } } , ".
            "(. + {".
            "dtLastLoad: \$dtLastLoad, ".
            "fullname: (.systemNumber+\": \"+.name)".
            "} ".
            ") ".
            "end ) ".
            "catch (".
            "{ index: { _id: \"__noop__\" } },".
            "{ fullname: \"noop\", error: . } ".
            ")";
         if ($session->{loopCount}==0){
            $session->{LastRequest}=0;
         
            return($self->ORIGIN_Load_BackCall(
                "/v1/systems/catalog",
                           $credentialName,$indexname,
                           $ESjqTransform,$opNowStamp,
                $session,$meta)
            );
         }
         elsif ($session->{loopCount}>0){
            return(undef);
         }
         return(undef);
      },$indexname,{
        session=>{loadParam=>$loadParam},
        jq=>{
          arg=>{
             dtLastLoad=>$opNowStamp
          }
        },
        curl=>{
          ignore_no_proxy=>1,
          arg=>{
             '-d'=>'{}'
          }
        }
      }
   );

   if (ref($res) ne "HASH"){
      msg(ERROR,"something went wrong '$res' in ".$self->Self());
   }
   msg(INFO,"ESrestETLload result=".Dumper($res));
   return($res,$emsg);
}




sub ESprepairRawRecord
{
   my $self=shift;
   my $rec=shift;


 #  print STDERR Dumper($rec);

}





sub getDetailBlockPriority
{
   my $self=shift;
   my $grp=shift;
   my %param=@_;
   return(qw(header default orgs apps contacts  source));
}



sub isViewValid
{
   my $self=shift;
   my $rec=shift;
   return("default") if (!defined($rec));
   return("ALL");
}

sub isWriteValid
{
   my $self=shift;
   my $rec=shift;
   return(undef);
}

sub isQualityCheckValid
{
   my $self=shift;
   my $rec=shift;
   return(0);
}

sub isUploadValid
{
   my $self=shift;
   my $rec=shift;
   return(0);
}



1;
