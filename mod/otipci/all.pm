package otipci::all;
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
use otipci::lib::Listedit;
use JSON;
use MIME::Base64;
@ISA=qw(kernel::App::Web::Listedit kernel::DataObj::ElasticSearch 
        otipci::lib::Listedit);


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
            name          =>'class',
            group         =>'source',
            dataobjattr   =>'_source.class',
            label         =>'class'),

      new kernel::Field::CDate(
            name          =>'cdate',
            group         =>'source',
            label         =>'Creation-Date',
            dataobjattr   =>'_source.sys_created_on'),

      new kernel::Field::MDate(
            name          =>'mdate',
            group         =>'source',
            label         =>'Modification-Date',
            dataobjattr   =>'_source.sys_updated_on'),

      new kernel::Field::Date(     
            name          =>'srcload',
            dataobjattr   =>'_source.otip_version',
            ElasticType   =>'keyword',
            searchable    =>0,
            group         =>'source',
            htmldetail    =>'NotEmpty',
            label         =>'Source-Load'),

      new kernel::Field::Text(
            name          =>'srcsys',
            group         =>'source',
            label         =>'Source-System',
            dataobjattr   =>'_source.u_data_source'),

      new kernel::Field::Text(
            name          =>'srcid',
            group         =>'source',
            label         =>'Source-Id',
            dataobjattr   =>'_source.u_external_id'),

   );
   $self->setDefaultView(qw(id class ));
   $self->LimitBackend(10000);
   return($self);
}


sub getCredentialName
{
   my $self=shift;

   return("otipci");
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
              version=>20
           },
           properties=>{
              name    =>{type=>'text',
                         fields=> {
                             keyword=> {
                               type=> "keyword",
                               ignore_above=> 256
                             }
                           }
                         },
              class   =>{type=>'text',
                         fields=> {
                             keyword=> {
                               type=> "keyword"
                             }
                           }
                         },
              sysid   =>{type=>'text',
                         fields=> {
                             keyword=> {
                               type=> "keyword"
                             }
                           }
                         },
              psys_id=>{type=>'text',
                         fields=> {
                             keyword=> {
                               type=> "keyword"
                             }
                           }
                         },
              fullname=>{type=>'text',
                         fields=> {
                             keyword=> {
                               type=> "keyword",
                               ignore_above=> 256
                             }
                           }
                         },
              otip_version=>{type=>'date'}
           }
        }
      },sub {
         my ($session,$meta)=@_;

         my $toffset="1970-01-01T00:00:00Z";
         my $idgt=".";
         my $limit=1000;
         my $ESjqTransform=
            "def to_utc: ".
            "capture(\"(?<dt>\\\\d{4}-\\\\d{2}-\\\\d{2})T".
            "(?<tm>\\\\d{2}:\\\\d{2}:\\\\d{2})(?<off>[+-]\\\\d{2}):".
            "(?<min>\\\\d{2})\")".
            "| ( .dt + \"T\" + .tm + \"Z\" | fromdateiso8601 )".
            "- ( ( .off | ltrimstr(\"+\") | tonumber ) * 3600 ".
            "+ ( .min | tonumber ) * 60 ) ".
            "| strftime(\"\%Y-\%m-\%d \%H:\%M:\%S\"); ".
            "".
            "def to_utc_safe: ".
            "if (type==\"string\") then to_utc else . end; ".
            "".
            "try( ".
            "fromjson | ".
            "if (type!=\"array\" or length == 0) ".
            "then error(\"unexpected input - no array\") ".
            "else  .[] ".
            "| .sys_created_on |= to_utc_safe ".
            "| .sys_updated_on |= to_utc_safe ".
            "| .install_date   |= to_utc_safe ".
            "| { index: { _id: .otip_id } } , ".
            "(. + {".
            "dtLastLoad: \$dtLastLoad, ".
            "fullname: (.class+\": \"+.name)".
            "} ".
            "+ if has(\"cmdb_ci\") ".
               "then {psys_id:.cmdb_ci.id} ".
               "else ".
                 "if has(\"nic\") ".
                 "then {psys_id:.nic.id} ".
                 "else {psys_id:\"none\"} ".
                 "end ".
               "end ".
            ") ".
            "end ) ".
            "catch (".
            "{ index: { _id: \"__noop__\" } },".
            "{ fullname: \"noop\", error: . } ".
            ")";
         if ($session->{loopCount}==0){
            $session->{LastRequest}=0;
            $session->{decodeRawDump}=1;
            $session->{decodeJqDump}=1;
         
            return($self->ORIGIN_Load_BackCall(
                "/configItem?limit=$limit",
                           $credentialName,$indexname,
                           $ESjqTransform,$opNowStamp,
                $session,$meta)
            );
         }
         elsif ($session->{loopCount}>0){
            my $recCount=0;
            if (ref($session->{RawDump}) ne "ARRAY"){
               msg(INFO,"break Session due not existing RawDump");
            }
            else{
               $recCount=$#{$session->{RawDump}};
            }

            if ($recCount==-1){
               msg(INFO,"break Session due empty RawDump");
               return(undef);
            }
            else{
               if (ref($session->{RawDump}) ne "ARRAY"){
                  msg(ERROR,"unexpected RawDump from configItem call result:".
                            Dumper($session->{RawDump}));
                  return("ERROR");
               }
               my $lastRec=$session->{RawDump}->[$recCount];
               #print STDERR "lastRec=".Dumper($lastRec);
               $idgt=$lastRec->{otip_id};
               $toffset=$lastRec->{otip_version};
            }
            return($self->ORIGIN_Load_BackCall(
                "/configItem?limit=$limit&toffset=$toffset&id.gt=$idgt",
                           $credentialName,$indexname,
                           $ESjqTransform,$opNowStamp,
                $session,$meta)
            );
         }
         return(undef);
      },$indexname,{
        session=>{loadParam=>$loadParam},
        jq=>{
          arg=>{
             dtLastLoad=>$opNowStamp
          }
        }
      }
   );
   if (ref($res) ne "HASH"){
      msg(ERROR,"something went wrong '$res' in ".$self->Self());
   }
   #msg(INFO,"ESrestETLload result=".Dumper($res));
   return($res,$emsg);
}




sub ESprepairRawRecord
{
   my $self=shift;
   my $rec=shift;


#   ########################################################################
#   # shorname generation
#   $rec->{'_source.shortname'}=$rec->{'_source.name'};
#   $rec->{'_source.shortname'}=~s/[^_ a-z0-9-].*$//i;
#   if (length($rec->{'_source.shortname'})<3){
#      $rec->{'_source.shortname'}=$rec->{'_source.name'};
#      $rec->{'_source.shortname'}=~s/[^_ a-z0-9-]+//i;
#      $rec->{'_source.shortname'}=~s/[^_ a-z0-9-].*$//i;
#   }
#   if (length($rec->{'_source.shortname'})<2){
#      $rec->{'_source.shortname'}=$rec->{'_source.ictoNumber'}."_".
#                                  $rec->{'_source.shortname'};
#   }
#   $rec->{'_source.shortname'}=limitlen($rec->{'_source.shortname'},35);
#   $rec->{'_source.shortname'}=~s/[_ -]+$//g;
#   ########################################################################
#   foreach my $f (qw(_source.lifecycle.endOfLife
#                     _source.lifecycle.phaseOut
#                     _source.lifecycle.active)){
#      if (exists($rec->{$f}) && $rec->{$f} ne ""){
#         $rec->{$f}.=" 12:00:00";
#      }
#   }
#   if (exists($rec->{'_source.itOwnerIds'})){
#      $rec->{'_source.relatedOrganizationIds'}=$rec->{'_source.itOwnerIds'};
#   }

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
