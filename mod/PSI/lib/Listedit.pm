package PSI::lib::Listedit;
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
use Text::ParseWords;
use Digest::MD5 qw(md5_base64);

sub new
{
   my $type=shift;
   my %param=@_;
   my $self=bless($type->SUPER::new(%param),$type);
   return($self);
}


sub ORIGIN_Load_BackCall
{
   my $self=shift;
   my $originSubPath=shift;
   my $credentialName=shift;
   my $indexname=shift;
   my $ESjqTransform=shift;
   my $opNowStamp=shift;

   my $session=shift;
   my $meta=shift;
   
   my ($baseurl,$apikey,$apiuser)=$self->GetRESTCredentials($credentialName);

   my $dtLastLoad;
   if (exists($meta->{dtLastLoad})){
      $dtLastLoad=$self->ExpandTimeExpression($meta->{dtLastLoad},
                                              "en","GMT","GMT");
      msg(INFO,"dtLastLoad from meta=$dtLastLoad");
   }
   if ($dtLastLoad ne ""){
      my $fullLoadAfter=10080; # do a full load, if last
                               # fullload is older then 7d
      my $d=CalcDateDuration($dtLastLoad,NowStamp("en"));
      if ($d->{totalminutes}>$fullLoadAfter){
         $dtLastLoad=undef;  
      }
      my $MetalastEScleanupIndex=$meta->{lastEScleanupIndex};
      my $lastEScleanupIndex=$self->ExpandTimeExpression(
                         $MetalastEScleanupIndex,"en","GMT","GMT");
      if ($lastEScleanupIndex ne ""){ 
         my $d=CalcDateDuration($lastEScleanupIndex,NowStamp("en"));
         if (defined($d)){
            if ($d->{totalminutes}>$fullLoadAfter){
               $dtLastLoad=undef;    
            }
            msg(INFO,"lastEScleanupIndex=$lastEScleanupIndex - ".
                      int($d->{totalminutes})."min. old");
         }
         else{
            msg(WARN,"lastEScleanupIndex=$lastEScleanupIndex - broken!");
         }
      }
      else{
         $dtLastLoad=undef;
      }
   }
   msg(INFO,"dtLastLoad after fullLoadAfter handling=$dtLastLoad");
   if (exists($session->{loadParam}->{full}) &&
       $session->{loadParam}->{full}==1 &&
       $session->{loopCount}==0){
      msg(WARN,"inititiate full load by loadParam");
      $dtLastLoad=undef;
   }
   msg(INFO,"dtLastLoad after Param and loopCount handling=$dtLastLoad");
 
   if (($baseurl=~m#/$#)){
      $baseurl=~s#/$##; 
   }
   #msg(INFO,"ORIGIN_Load: baseurl=$baseurl");
   my $restOriginFinalAddr=$baseurl.$originSubPath;
   if ($dtLastLoad ne "" && $session->{loopCount}==0){
      msg(INFO,"ESrestETLload: DeltaLoad since $meta->{dtLastLoad}");
      if ($session->{loopCount}==0 && !($restOriginFinalAddr=~m/toffset=/)){
         msg(INFO,"ESrestETLload: add toffset to restOriginFinalAddr");
         if ($restOriginFinalAddr=~m/\?/){
            $restOriginFinalAddr.="&toffset=$meta->{dtLastLoad}";
         }
         else{
            $restOriginFinalAddr.="?toffset=$meta->{dtLastLoad}";
         }
      }
      $session->{EScleanupIndex}={
          bool=>{
            should=>[
               {
                 match=>{
                  otip_deleted=>\1
                 }
               },
               {
                 match=>{
                    _id=>'__noop__'
                 }
               }
            ],
            'minimum_should_match'=>'1'
          } 
      };
   }
   else{
      #msg(INFO,"ESrestETLload: load with EScleanupIndex");
      #msg(INFO,"ESrestETLload: EScleanupIndex 1: opNowStamp=$opNowStamp");

      if (1){ # as a test, we delete records without update within last 365d
         $opNowStamp=$self->ExpandTimeExpression($opNowStamp."-365d",
                                                 "ISO","GMT","GMT");
      }
      msg(INFO,"ESrestETLload: EScleanupIndex opNowStamp=$opNowStamp");

      $session->{EScleanupIndex}={
          bool=>{
            should=>[
               {
                 range=>{
                    dtLastLoad=>{
                       lt=>$opNowStamp
                    }
                 }
               },
               {
                 match=>{
                    _id=>'__noop__'
                 }
               }
            ],
            'minimum_should_match'=>'1'
          } 
      };
   }
   msg(INFO,"ORIGIN_Load: restOriginFinalAddr=$restOriginFinalAddr");
   
   my @restOriginHeaders=(
       'X-CUSTOMER-ACCESS-TOKEN'=>$apikey,
       'Content-Type'=>'application/json'
   );
   return("GET",$restOriginFinalAddr,\@restOriginHeaders,$ESjqTransform);
}






1;
