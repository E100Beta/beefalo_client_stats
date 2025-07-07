====================
Beefalo Client Stats
====================
Makes best effort guesses about your beefalo current stats
for easier domestication and ornery obedience management.

EPICS
=====
- [ ] _`UI`
- [ ] _`Bell Tracker Component`
- [ ] _`Beefalo Tracker Component`


TODO
====
- [ ] OnSave, OnLoad `#bell_tracker`_ `#beefalo_tracker`_
    - need to do after everything when I'm sure core concept is fine
- [ ] salt lick pausing domestication `#beefalo_tracker`_
    - [ ] `dropitem` handler
    - A way to cancel it if we see another player on our beefalo?
- [ ] thread to wait on next animation until idle `#beefalo_tracker`_
    - we need a way to check for vomiting/farting, maybe even begging?
    - I think we should do like an animation watcher that's constantly running, that'll be much easier
- [ ] put an indicator on how confident we are in a particular stat's accuracy `#ui`_
- [ ] check attacking beefalo `#beefalo_tracker`_
- [ ] put tendency detection in another file?
- [ ] make a share command and reader for said command
    - Probably need to look at Environment Pinger. I think format should be like:
      > /bcs_share
      > BCS: share <GUID>:<last_update>:<domestication>:<hunger>:<obedience>



IN PROGRESS
===========
- [ ] basic ui `#ui`_
    - as far as I understood, we need a Badge widget that's
      based on mightybadge (and maybe wigfrid thing) and then
      hack it into widgets/statusdisplays with a postconstruct.
      Also 2477889104 has a pretty good implementation.

DONE
====
- [x] basic api `#bell_tracker`_
- [x] basic api `#beefalo_tracker`_
- [x] StartTask, CancelTask `#beefalo_tracker`_
- [x] Heat and Shaved `#beefalo_tracker`_
- [x] Wigfrid skills `#beefalo_tracker`_



.. _#ui: #ui
.. _#bell_tracker: #bell-tracker-component
.. _#beefalo_tracker: #beefalo-tracker-component

..
  vim: set nowrap ts=4 sw=4: