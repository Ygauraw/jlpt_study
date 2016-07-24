#!/usr/bin/perl

use strict;
use warnings;

use YAML::XS qw(DumpFile);
use Util::XML_YAML_Perl;

my $obj=Util::XML_YAML_Perl->new();

my $perl_ref=$obj->xml_to_perl("kanjivg-20160426.xml");

DumpFile("kanjivg-20160426.yaml",$perl_ref);
