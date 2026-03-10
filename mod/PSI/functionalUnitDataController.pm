package PSI::functionalUnitDataController;
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
      new kernel::Field::Text(     
            name          =>'id',
            searchable    =>0,
            group         =>'source',
            dataobjattr   =>'_id',
            label         =>'Id'),

      new kernel::Field::Text(     
            name          =>'email',
            searchable    =>0,
            dataobjattr   =>'email',
            label         =>'EMail'),

      new kernel::Field::Text(     
            name          =>'firstName',
            searchable    =>0,
            dataobjattr   =>'firstName',
            label         =>'firstName'),

      new kernel::Field::Text(     
            name          =>'lastName',
            searchable    =>0,
            dataobjattr   =>'lastName',
            label         =>'lastName'),

   );
   $self->setDefaultView(qw(id));
   $self->LimitBackend(10000);
   return($self);
}


sub getCredentialName
{
   my $self=shift;

   return("PSI");
}


sub ESindexName
{
   my $self=shift;

   my $indexname=lc($self->Self());
   $indexname="psi__system";
   return($indexname);
}


sub ESprepairRawResult
{
   my $self=shift;
   my $data=shift;

   my @subRec;

   map({
      my @localSub=[];
      if (exists($_->{'_source'}) &&
          exists($_->{'_source'}->{'functionalUnitDataControllers'}) &&
          ref($_->{'_source'}->{'functionalUnitDataControllers'}) eq "ARRAY"){
         @localSub=@{$_->{'_source'}->{'functionalUnitDataControllers'}};
      }
      foreach my $lrec (@localSub){
         $lrec=FlattenHash($lrec);
         $lrec->{_id}=$_->{_id};
         if ($self->can("ESprepairRawRecord")){
            $self->ESprepairRawRecord($lrec);
         }
         push(@subRec,$lrec);
      }
   } @$data);

   @$data=@subRec;
}


sub ESprepairRawRecord
{
   my $self=shift;
   my $rec=shift;

#   print STDERR Dumper($rec);

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
