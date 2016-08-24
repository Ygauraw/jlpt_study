package Learnable;

# Attempt to have a unified approach to tracking learning status of various
# different things. 
#
# First, have a single integer variable to track the learning status
# of an item:
#
# negative: not learning, put off until later (abs(value) ~= future date)
# zero    : not learning (not enrolled)
# +1      : in active learning
# +2      : in active review
# +3 up   : in SRS review
#
# Second, have a basic type system. I may implement this using either
# class inheritance or roles (giving Moose a try)/interfaces. For
# example:
#
# Learnable
#   +-- Vocabulary
#   |     +-- JLPT
#   |     +-- Core2k
#   |     +-- Core6k
#   |     +-- ...
#   +-- Kanji
#   :
#   +-- Podcasts
#   :
#
# The exact hierarchy isn't too important. The most important aspects are:
#
# * each class represents a set of objects that can potentially be learned
# * class names will be stored in a database
# * classes provide for a total ordering and key lookup on their sets
# * everything derives from Learnable
# * Learnable base class provides unified database storage of statuses
# * for sets that can grow, subclass should provide a history ("clock") feature
# * Learnable base class will provide method of randomly selecting
#   some subset of items using a seed and a clock (generates the same subset all
#   the time)
# * Subclass may also provide methods to enable eaiser embedding in UI

# So the above basically involves three feature areas:
#
# 1  Tracking status of learnables
#
# 2  Generating and remembering random subsets of things not yet enrolled
#
# 3. Helping with embedding learnables in UI

# Taking the last point first, consider that several applications
# might display selections of vocabulary, and that at the point of
# presentation to the user, we would like to be able to see and change
# the learnable status of those vocabulary.
#
# For the second point, the idea is to generate a random selection of
# learnable items that the user has not yet enrolled. This would be
# done every day, and it would be up to the user to decide which items
# they're interested in studying. So it's about suggesting items
# rather than saying "you must learn these today". These lists would
# be stored daily and the user could check them to see how many they
# managed to enrol.
#
# My initial idea was to store a random seed and use that to
# (re)generate the list, but this would require being able to "rewind"
# the status of items to the state when the list was created. This
# could be done with an append-only data structure, but it would
# probably end up taking up as much space as simply storing the lists
# as snapshots at a particular time, and would be more complicated,
# too. Besides needing to track/rewind statuses (so that the list
# generator knows what the unenrolled items were at a particular
# time), any database that the subclass provided would also have to
# have a rewind ability.
#
# I already covered the status code. The base class would also provide
# for storing other related information, such as:
#
# * timestamps for when status changed
# * other annotation fields such as difficulty, user tags and user notes
# * what negative and positive SRS numbers mean (in terms of days)
# * number of reviews/percentage of review completed
# * generic lists
# * cross-references?
#


use Moose;




