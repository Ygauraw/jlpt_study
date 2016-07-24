#!/usr/bin/perl

use strict;
use warnings;

use YAML::XS qw(DumpFile);
use Util::XML_YAML_Perl;

my $obj=Util::XML_YAML_Perl->new();

my $perl_ref=$obj->xml_to_perl("JMdict.xml");

DumpFile("JMdict.yaml",$perl_ref);
