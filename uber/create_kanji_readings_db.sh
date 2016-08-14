#!/bin/bash

rm kanji_readings.sqlite
sqlite3 kanji_readings.sqlite <Model/kanji_readings.sql
./check_vocab_readings.pl --makedb
