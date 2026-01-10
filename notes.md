Notes
=====

I have a problem: When a ruler dies, a new ruler must be selected. The
death of a ruler is an event, which should trigger another event: the
selection of a sucessor. But how to architect this? Currently the
event goes on the character event list. And the civilization gets
'told' about all character events that happen during a given tick. So
is it the _civilization_ that should react and select a new ruler? Or
is it the characters in that civilization that do it? In some sense
it's the civ that does it by virtue of the succession laws that are in
place. For example, the british crown automatically passes to the
first born, it's the civ that does that. If the prime minister of GB
died, I'm not sure what would happen actually. But it would probably
come down to what the party in government decided in practice.

So let's say it's an action that the civ takes, at least for now. That
introduces a problem with my architecture though: there's no place
currently to do that. There are character events and civ events, but
no means for a civilization to _act_ based on the occurance of a
particular event. There's not even any way for a civ to know about a
character event. The ticks are different too: character ticks are
daily, civs yearly.

Maybe character events within a civ get 'broadcast' to that civ (and
maybe to other civs that have good intelligence networks) and the the
civ will queue up a set of actions to take on its tick. Or I could
make the civ have a daily, as opposed to yearly, tick. The character
loop already has a 'special' first of the year tick where annual
actions happen (death being one of them - death happens on the first
day of the year. Which I suppose technically would mean the civ has no
ruler for a year)

Misc grab bag of planned features
---------------------------------

- Civs can demand tribute from other this.
