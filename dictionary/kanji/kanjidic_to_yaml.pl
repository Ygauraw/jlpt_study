#!/usr/bin/perl

use strict;
use warnings;

use YAML::XS qw(DumpFile);
use Util::XML_YAML_Perl;

my $obj=Util::XML_YAML_Perl->new();

my $perl_ref=$obj->xml_to_perl("kanjidic2.xml");

DumpFile("kanjidic2.yaml",$perl_ref);
