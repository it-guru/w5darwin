package otipci::ipaddress;
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
            name          =>'fullname',
            searchable    =>0,
            dataobjattr   =>'_source.fullname',
            label         =>'fullname'),

      new kernel::Field::Text(     
            name          =>'name',
            dataobjattr   =>'_source.u_real_name',
            label         =>'name'),

#      new kernel::Field::Text(     
#            name          =>'systemid',
#            dataobjattr   =>'_source.u_external_id',
#            label         =>'SystemID'),

      new kernel::Field::Text(     
            name          =>'statusid',
            dataobjattr   =>'_source.install_status.id',
            htmldetail    =>'0',
            label         =>'StatusID'),

      new kernel::Field::Text(     
            name          =>'status',
            dataobjattr   =>'_source.install_status.name',
            label         =>'Status'),

      new kernel::Field::Text(     
            name          =>'opstatus',
            dataobjattr   =>'_source.operational_status.name',
            label         =>'Operational-Status'),


#      new kernel::Field::TextDrop(
#            name          =>'assignmentgroup',
#            label         =>'Assignment Group (OwnerGroup)',
#            dataobjattr   =>"_source.u_owner_group.name"),
#
#      new kernel::Field::TextDrop(
##            name          =>'iassignmentgroup',
#            label         =>'Incident Assignment Group (SupportGroup)',
#            dataobjattr   =>"_source.support_group.name"),
#


#      new kernel::Field::Float(
#            name          =>'systemcorecount',
#            label         =>'System core count (new!)',
#            unit          =>'CPU',
#            precision     =>0,
#            dataobjattr   =>'_source.cpu_core_count'),
#
#      new kernel::Field::Float(
#            name          =>'systemcpucount',
#            label         =>'System CPU count',
#            unit          =>'CPU',
#            precision     =>0,
#            dataobjattr   =>'_source.cpu_count'),
#
#      new kernel::Field::Float(
#            name          =>'systemcpuspeed',
#            label         =>'System CPU speed',
#            unit          =>'MHz',
#            precision     =>0,
#            dataobjattr   =>'_source.cpu_speed'),
#
#      new kernel::Field::Text(
#            name          =>'systemcputype',
#            label         =>'System CPU type',
#            dataobjattr   =>'_source.cpu_type'),
#
#      new kernel::Field::Float(
#            name          =>'systemmemory',
#            label         =>'System Memory',
#            unit          =>'MB',
#            precision     =>0,
#            dataobjattr   =>'_source.ram'),
#
#
#      new kernel::Field::Text(
#            name          =>'systemos',
#            label         =>'System OS',
#            dataobjattr   =>'_source.os.name'),
#




#      new kernel::Field::Text(
#            name          =>'model',
#            label         =>'Model',
#            dataobjattr   =>'_source.model_id.name'),
#
#      new kernel::Field::Text(
#            name          =>'category',
#            label         =>'Category',
#            dataobjattr   =>'_source.category'),
#
#      new kernel::Field::Text(
#            name          =>'classification',
#            label         =>'Classification',
#            dataobjattr   =>'_source.classification.name'),
#
#      new kernel::Field::Text(
#            name          =>'usage',
#            label         =>'Usage',
#            dataobjattr   =>"_source.u_usage"),

#      new kernel::Field::Text(
#            name          =>'environment',
#            label         =>'Environment',
#            dataobjattr   =>'_source.environment.name'),
#
#
#      new kernel::Field::Text(
#            name          =>'altname',
#            label         =>'second name',
#            dataobjattr   =>'_source.u_customer_ci_name'),
#
#
#
#      new kernel::Field::Text(     
#            name          =>'category',
#            searchable    =>0,
#            group         =>'source',
#            dataobjattr   =>'_source.category',
#            label         =>'category'),
#
#      new kernel::Field::Text(     
#            name          =>'subcategory',
#            dataobjattr   =>'_source.subcategory',
#            label         =>'Sub-Category'),


      new kernel::Field::Text(
            name          =>'sys_id',
            searchable    =>0,
            group         =>'source',
            dataobjattr   =>'_source.sys_id',
            label         =>'ServiceNow sys_id'),

      new kernel::Field::Text(     
            name          =>'p_sys_id',
            group         =>'source',
            dataobjattr   =>'_source.üsys_id',
            label         =>'Parent sys_id'),


      new kernel::Field::Text(     
            name          =>'class',
            searchable    =>0,
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

# "otip_version": "2025-12-01T06:05:44.0Z",
#    "sys_id": "7a95c2f36bbcf0d047df9974ab63fb81",
#    "otip_id": "7a95c2f36bbcf0d047df9974ab63fb81",
#    "otip_deleted": true,
#    "class": "cmdb_ci_server",
#    "u_mandator_key": "A000A53E.000000"


   $self->setDefaultView(qw(id systemid name status model category 
                            classification usage));
   $self->LimitBackend(10000);
   return($self);
}


sub getCredentialName
{
   my $self=shift;

   return("otipci");
}


sub ESindexName
{
   my $self=shift;

   return("otipci__all");
}


sub SetFilter
{
   my $self=shift;

   my $flt=$_[0];

   if (ref($flt) eq "HASH"){
      $_[0]->{class}="cmdb_ci_ip_address";
   }

   return($self->SUPER::SetFilter(@_));
}


sub initSearchQuery
{
   my $self=shift;
   if (!defined(Query->Param("search_status"))){
     Query->Param("search_status"=>"\"Installed\"");
   }
}




sub ESprepairRawRecord
{
   my $self=shift;
   my $rec=shift;

   print STDERR Dumper($rec);

}





sub getDetailBlockPriority
{
   my $self=shift;
   my $grp=shift;
   my %param=@_;
   return(qw(header default source));
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
