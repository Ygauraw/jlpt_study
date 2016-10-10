# jlpt_study
Tools to help studying for the JLPT (Japanese Language Proficiency Test)

This is a collection of tools that I wrote to help me with my JLPT
study. It mainly involves collecting various resources that are
available on the net and making them usable on a desktop PC without
needing to be online all the time.

For each of the resources, the scripts here help to:

* download the data
* parse them (in the case of HTML data)
* put them into a database
* make some more study-related databases
* write GUI programs (with Perl/GTK2) that make use of the data

The web resources I'm using include the following. In some cases, you
will need a valid subscription to a particular website in order to
download the resources (these are marked with '$'):

* Jim Breen's Japanese vocab and kanji dictionaries;
* Kanji.koohii.com site for learning kanji based on Heisig's Remembering the Kanji
* www.jlptstudy.net for JLPT grammar, vocab and expression lists;
* tanos.co.uk  for JLPT grammar, vocab and expression lists;
* iknow.jp for Core 2k and Core 6k vocab lists (includes audio; $?)
* www.japanesepod101.com for Japanese learning podcasts ($)
* tatoeba.org for a corpus of translated sentences (many languages)

<hr>

This is a work in progress. I'm adding more features as I go on. For
now, the two main things that I have working (and use on a daily
basis) are:

* a simple interface for testing yourself on random samples of the
Core 2k/6k vocabulary lists (with kanji challenge and audio challenge
modes)
* a browser for kanji and vocab, graded by JLPT level (with support
for notes, marking items with learning status)

Going forward, the main things that I want to implement will be:

* integration of sentences (vocab in context)
* "spaced repetition" features (possibly by generating files suitable for input into Anki or Mnemnosyne, possibly a stand-alone program)
* history and scoreboard features (ie, track daily activity and percentage complete against target JLPT level)
* random selections (eg, generate a random selection of vocab for you to learn every day) and statistical tests to gauge how many vocab/kanji/whatever you know
* generic vocab database/explorer (kanji explorer doesn't include words written only with katakana, for example)
* implementing keywords/lists (eg, for grouping vocab by topic)
* explore graphical components of each kanji (using the "Remembering the Kanji" method)

## Kanji/Vocab Explorer

The main screen looks like this:

<img src="Screenshots/Screenshot-explore_kanji.pl.png?raw=true">

It uses the files from the KanjiVG project to display an image for the
kanji, including stroke order. It also summarises the regular "on" and
"kun" readings for the kanji, as well as information on JLPT level,
Jouyou kanji grade, and "Remembering the Kanji" keyword and frame
number. Vocab containing the kanji are also divided between vocab that
have regular on/kun readings (panel on the right) and those that don't
(panel on the bottom).

You can double-click on the kanji image to bring up information on that kanji:

<img src="Screenshots/Screenshot-Editing Kanji 射.png?raw=true">

Currently, you can add notes and change the learning status. I will
integrate the data from kanji.koohii.com (RTK-based "stories" to help
memorise how to draw the kanji) and implement the other "placeholder"
elements on this screen.

Double-clicking on a vocab entry brings up the vocab edit screen:

<img src="Screenshots/Screenshot-Editing Vocab 注射 (ちゅうしゃ).png?raw=true">

Here you can add notes and see definitions for the vocab. Since I'm
collating information from various sources, I don't have a definitive
English definition stored in the database. The "short definition"
entry box lets you add your own definition. It can be useful to see a
list of homonyms (words with the same sound) for each vocab, so I will
add that feature too.

Finally, one more screenshot from the kanji explorer:

<img src="Screenshots/Screenshot-explore_kanji.pl-2.png?raw=true">

This just shows the right-click context menu for a particular vocab
item. It shows how you can jump to different kanji, copy the kanji or
its reading into the system clipboard, mark a vocab as being an
"exemplar" for when learning kanji readings, as well as assign a
learning status.

## Core 2k/6k vocabulary tester

The main screen is a bit rough looking:

<img src="Screenshots/Screenshot-Core Vocabulary Tester.png?raw=true">

The buttons are there to add a new randomised test. Then you can
double click on the newly-created test.

There are eight buttons allowing for all combinations of three
different variables:

* sequential or random selection
* select from Core2k or Core6k lists
* selection of challenge mode: kanji (test reading) or sound (tests listening and writing)

Double-clicking on a test that you haven't finished yet brings up that
test.  The following shows a sample kanji challenge mode test:

<img src="Screenshots/Screenshot- Vocabulary Tester.png?raw=true">

This has all the bits you'd expect. You have to try to read the text
and then answer the questions based on whether you could
read/understand the vocab item/sentence.

When you click the button on the bottom, it shows the answer:

<img src="Screenshots/Screenshot- Vocabulary Tester-1.png?raw=true">

All the Core2k/Core6k entries have audio with them, so after clicking
to reveal the answer, the play button at the top right becomes active
so that you can pause/replay the audio (which auto-plays). The answer
radio buttons are active all the time so you can "pre-fill" answers
before seeing/hearing the translation.

There's also an audio/sound challenge mode, which looks like the following:

<img src="Screenshots/Screenshot- Vocabulary Tester-2.png?raw=true">

Here, the audio play/pause button is always active, so you can listen
as often as you want. The code can also display the standard volume
control in the white area, but I took it out since it wasn't really
useful.

Note that two of the questions are different from the kanji challenge
mode. The answers you give are stored in different fields in the
database so you can do SQL queries to look up, eg, vocab that you know
by ear, but can't write.

Finally, clicking the "show answer" button does what you expect:

<img src="Screenshots/Screenshot- Vocabulary Tester-3.png?raw=true">

That's it for this README. I will add more notes and detailed info in
the wiki pages here on github.