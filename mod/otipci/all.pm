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


# "otip_version": "2025-12-01T06:05:44.0Z",
#    "sys_id": "7a95c2f36bbcf0d047df9974ab63fb81",
#    "otip_id": "7a95c2f36bbcf0d047df9974ab63fb81",
#    "otip_deleted": true,
#    "class": "cmdb_ci_server",
#    "u_mandator_key": "A000A53E.000000"
#
#      new kernel::Field::Text(     
#            name          =>'fullname',
#            dataobjattr   =>'_source.fullname',
#            ElasticType   =>'keyword',
#            ignorecase    =>1,
#            label         =>'Fullname'),
#
#      new kernel::Field::Text(     
#            name          =>'name',
#            ElasticType   =>'keyword',
#            dataobjattr   =>'_source.name',
#            ignorecase    =>1,
#            label         =>'Name'),
#
#      new kernel::Field::Text(     
#            name          =>'shortname',
#            dataobjattr   =>'_source.shortname',
#            ignorecase    =>1,
#            label         =>'Shortname (gen by W5B)'),
#
#      new kernel::Field::Text(     
#            name          =>'ictoNumber',
#            caseignore    =>1,
#            ElasticType   =>'keyword',
#            dataobjattr   =>'_source.ictoNumber',
#            label         =>'ictoNumber'),
#
#      new kernel::Field::Date(     
#            name          =>'lifecycle_active',
#            dataobjattr   =>'_source.lifecycle.active',
#            dayonly       =>1,
#            label         =>'Active'),
#
#      new kernel::Field::Text(
#            name          =>'applmgremail',
#            label         =>'Application Manager',
#            searchable    =>0,
#            depend        =>['contacts'],
#            onRawValue    =>sub{
#               my $self=shift;
#               my $current=shift;
#
#               my $fld=$self->getParent->getField("contacts",$current);
#               my $contacts=$fld->RawValue($current);
#
#               my $applmgremail;
#               if (ref($contacts) eq "ARRAY"){
#                  foreach my $c (@{$contacts}){
#                     if (lc($c->{role}) eq lc("Application Manager - Cape") ||
#                         lc($c->{role}) eq lc("Application Manager")){
#                        $applmgremail=lc($c->{email});
#                     }
#                  }
#               }
#               return($applmgremail);
#            }),
#
#      new kernel::Field::Text(
#            name          =>'hubid',
#            label         =>'HUB-ID',
#            htmldetail    =>'NotEmpty',
#            depend        =>['orgs'],
#            group         =>'orgs',
#            onRawValue    =>sub{
#               my $self=shift;
#               my $current=shift;
#               my $fld=$self->getParent->getField("orgs",$current);
#               my $orgs=$fld->RawValue($current);
#
#               my $d;
#               if (ref($orgs) eq "ARRAY"){
#                  foreach my $orgrec (@{$orgs}){
#                     my $org=$orgrec->{name};
#                     if (my ($pref,$hubid)=$org=~m/^(E-){0,1}(HUB-[0-9]+)/){
#                        $d=$hubid;
#                        last;
#                     }
#                  }
#               }
#               return($d);
#            }),
#
#      new kernel::Field::Text(
#            name          =>'organisation',
#            label         =>'Organisation',
#            group         =>'orgs',
#            depend        =>['orgs'],
#            onRawValue    =>sub{
#               my $self=shift;
#               my $current=shift;
#
#               my $fld=$self->getParent->getField("orgs",$current);
#               my $orgs=$fld->RawValue($current);
#
#               my @orgnames;
#               if (ref($orgs) eq "ARRAY"){
#                  foreach my $orgrec (@{$orgs}){
#                     push(@orgnames,$orgrec->{name});
#                  }
#               }
#               @orgnames=sort(@orgnames);
#               my $orgstring=$orgnames[0];
#               if (my ($hubid,$ostr)=$orgstring=~m/^(HUB-[0-9]{3,5})\s+(.*)$/){
#                  my $vou=$self->getParent->getPersistentModuleObject(
#                      "vou","TS::vou"
#                  );
#                  if (defined($vou)){
#                     $vou->SetFilter({cistatusid=>\'4',hubid=>\$hubid});
#                     my ($hrec)=$vou->getOnlyFirst(qw(name shortname));
#                     if (defined($hrec) && $hrec->{shortname} ne ""){
#                        $orgstring="E-".$hubid." ".$hrec->{shortname}." ".$ostr;
#                     }
#                  }
#               }
#               return($orgstring);
#            }),
#
#      new kernel::Field::Date(
#            name          =>'srcload',
#            history       =>0,
#            group         =>'source',
#            label         =>'Source-Load',
#            dataobjattr   =>'_source.dtLastLoad'),
#
#      new kernel::Field::MDate(
#            name          =>'mdate',
#            group         =>'source',
#            label         =>'Modification-Date',
#            dataobjattr   =>'_source.lastUpdated'),

   );
   $self->setDefaultView(qw(id ));
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
              version=>17
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
           "def to_utc:\n".
           "capture(\"(?<dt>\\\\d{4}-\\\\d{2}-\\\\d{2})T".
           "(?<tm>\\\\d{2}:\\\\d{2}:\\\\d{2})(?<off>[+-]\\\\d{2}):".
           "(?<min>\\\\d{2})\")".
           "| ( .dt + \"T\" + .tm + \"Z\" | fromdateiso8601 )".
           "- ( ( .off | ltrimstr(\"+\") | tonumber ) * 3600 ".
           "+ ( .min | tonumber ) * 60 ) ".
           "| strftime(\"\%Y-\%m-\%d \%H:\%M:\%S\");\n\n".
            "try( ".
            "fromjson | ".
            "if (type!=\"array\" or length == 0) ".
            "then error(\"unexpected input - no array\") ".
            "else  .[] ".
            "| .sys_created_on |= to_utc ".
            "| .sys_updated_on |= to_utc ".
            "| .install_date   |= to_utc ".
            "| { index: { _id: .otip_id } } , ".
            "(. + {".
            "dtLastLoad: \$dtLastLoad, ".
            "fullname: (.class+\": \"+.name)".
            "}) ".
            "end ) ".
            "catch (".
            "{ index: { _id: \"__noop__\" } },".
            "{ fullname: \"noop\" } ".
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
