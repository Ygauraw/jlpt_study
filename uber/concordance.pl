#!/usr/bin/perl

use strict;
use warnings;

use UFT8;			# only because of UTF-8 in comments

##
## About
##
#
# Program to aid in gathering data about kanji as presented in
# Heisig's "Remembering the Kanji". I had thought that the data would
# be freely available in combined form, but apparently not. I have a
# few data sources to reconcile:
#
# [words] http://nihongo.monash.edu/heisigwords.html
#
# 3,007 keyword/kanji pairs, apparently blessed by the man himself.
# This obviously includes kanji from RTK 3, but it's not clear what
# edition of RTK 1 was used as a source. The web page seems to use
# EUC-JP encoding, so I've converted it to a UTF-8 version using
# iconv.
#
# [heisig35] http://ziggr.com/heisig/
#
# All the kanji, stroke counts, frame numbers and keywords for
# editions 3 through 5. A UTF-8 machine-readable version is available.
#
# [breen] http://www.edrdg.org/kanjidic/kanjd2index.html
#
# Jim Breen's Kanji Dictionary. Available for download in various
# forms. I'm using the UTF-8 XML (kanjidic2.xml) file.
#
# This has kanji and the corresponding 6th-edition frame numbers (as
# well as some other unspecified edition numbering).
#
### Other sources, which I won't use (yet): ####
#
# http://www.lentoman.net/wiki/index.php?title=Remembering_The_Kanji_List
#
# A partial list, up to #1500. It doesn't mention any particular
# edition. It does denote keywords (such as baseball) that aren't
# actual kanji meanings, but are often used in stories.
#
# http://ankiweb.net
#
# I have a flashcard deck that purports to have all the kanji (and
# their variants), frame number and keywords along with other
# less-useful information (alternative keywords, jouyou level). I
# think it should be possible to extract this data using the sqlite
# command-line interface or DBI/DBD, but I know for a fact that there
# is at least one error in there (town and village keywords being
# swapped) and I still have to fully investigate Anki's database
# schema before I can extract the data.

##
## Approach
##
#
# My aim is to create a single database that includes the most correct
# information as gleaned from a concordance of the three sources. I'll
# use an SQLite database since it's easiest.
#
# I'll break up the problem into stages:
#
# * scan in the relevant data from each of the different sources into
#   separate tables
#
# * for the concordance, read all data sets into memory and look for
#   anomalies, outputting results to stdout
#
# * modify the program using heuristics (eg, prefer one information
#   source over another for certain fields) to cut down on the anomaly
#   report
#
# * go through an interactive stage, whereby I consult my paper copy
#   of the book to get definitive data to solve anomalies (results to
#   go into an "override" table)
#
# * populate the final, definitive table using overrides in
#   conjunction with the existing concordance routine.


##
## Schema Basics
##
#
# Everything needs to be UTF-8, with the appropriate flag set in the
# DBI/DBD layer to ensure that Perl knows we're dealing with UTF-8
# throughout so there's no double-encoding or whatever. All input
# files should already be in UTF-8.
#
# The main field that everything is going to be indexed on is the
# kanji itself since that appears in all three sources. I'll deal with
# the question of variants of the same kanji below, but at a minimum,
# for the concordance I will need to summarise the count of kanji that
# appears only in one source, while listing all those kanji that
# appear in two sources, but not the third.
#
# [words] is going to be my main source of information about keywords.
# It has various entries with special markup within the keyword field,
# eg:
#
#  壱   I (one)
#  逸   deviate/elude
#  薗   park [alternate]
#  鉛   lead (metal)
# 
# I'm not sure right now whether there are any rules at work here. I
# guess that the best thing to do will be to sort out such details at
# the concordance and manual stages.
#
# I can check these (kanji,keyword) pairs directly against
# [heisig35], but nothing else.
#
# [heisig35] has stroke count (same across all editions), local
# position in the file (useless information, apart from being a
# self-test of the file itself) and keywords as they appear in the
# 3rd, 4th and 5th editions. Lesson numbers are also included, as are
# frame numbers. I suspect that frame numbers vary across editions,
# but that the ones included here are for the 5th edition.
#
# A quick scan of the same kanji as mentioned before gives me:
#
# 457:壱:I (one):I (one):I (one):7:389:18
# 1973:逸:deviate:elude:elude:11:1254:53
# (no match for 薗, leading me to understand this is in RTK 3)
# 794:鉛:lead (metal):lead (metal):lead (metal):13:1624:24
#
# So this casts light on deviate/elude, which refers to keywords as
# used in different editions, and I (one) and lead (metal) which are
# either included for different meanings or for disambiguation.
# 
# [breen] should have the most up-to-date frame numbers, but I would
# still have to check against [heisig35]. I will also have to check
# the <variant> tags (which give variant kanji renderings) with each
# record and cross-reference them against [words]. I'm not sure if
# Heisig gives all variants their own frame.
# 
# At any rate, I want to record frame number, stroke count and variant
# information (in a second table, since this is one to possibly many)
# from this source. I think that it would also be good to extract the
# Unicode address (16-bit) for each kanji, and possibly other
# information. Even though this isn't going to be of use for the
# concordance, it could be useful later on, such as, eg, for looking
# up KanjiVG stroke order diagrams.

##
## Override Schemas
##
#
# These will evolve as I get to grips with the outputs of the
# concordance stage. Right now, I'm thinking of overrides as being
# something that is done to modify data coming back from databases
# before the concordance (or other) stage operates on it. That seems
# like the most logical way to handle it since it's least likely to
# cause breakage once I start tweaking the code.

##
## Output Schemas
##
#
# There will be two main indexes, both of equal importance: the kanji
# character and the keyword text. Both must be unique and, in the case
# of the keyword text, well-formed (so disambiguation info like
# lead(metal) are OK, but things like deviate/elude are right out)
#
# Some information like legitimate secondary readings (eg,
# former/increase) or "mnemonic" readings (nine/baseball) probably
# won't be included in my sources, so I'll have to add them later, as
# a separate table (indexed by the foreign key of the kanji itself).
# Or perhaps they can be included as well-formed strings in the main
# table.
#
# There will be no entry for primitives that don't have a frame
# number. I might try to find a way to include these later on as a
# separate table. I think that Heisig's keyword space is unique across
# both primitive-only and kanji characters (eg, wealth vs wealthy) so
# even though I may not be able to find stroke order diagrams for some
# of his "primitives" (eg, muzzle), I should at least be able to look
# up the page numbers, as he does in his index.
#
# I think that's basically it. I may include more information for
# purely informative purposes (like JLPT and Jouyou level, which are
# only available from [breen], but which are useful to have, even if
# there's no proper concordance information available) but I will draw
# the line there. So no story information, no information about
# revision history (for flashcard software) or other potential
# application-based data.
#



