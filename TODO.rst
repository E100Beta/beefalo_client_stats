====================
Beefalo Client Stats
====================
Makes best effort guesses about your beefalo current stats
for easier domestication and ornery obedience management.

EPICS
=====
- [ ] _`UI`
- [ ] _`Beefalo Tracker Component`
- [x] _`Bell Tracker Component`
    - removed, lmao


TODO
====
- [ ] salt lick pausing domestication `#beefalo_tracker`_
    - [ ] probably on unhook
    - A way to cancel it if we see another player on our beefalo?
- [ ] put tendency detection in another file?
- [ ] make a share command and reader for said command
    - Probably need to look at Environment Pinger. I think format should be like:
      | /bcs_share
      | BCS: share <GUID>:<last_update>:<domestication>:<hunger>:<obedience>

IN PROGRESS
===========
- [ ] thread to wait on next animation until idle `#beefalo_tracker`_
    - we need a way to check for vomiting/farting, maybe even begging?
    - I think we should do like an animation watcher that's constantly running, that'll be much easier
- [ ] OnSave, OnLoad `#beefalo_tracker`_
    - need to do after everything when I'm sure core concept is fine

- [ ] Test cases:
    - [ ] Picking up bonded bell of dead beefalo
    - [ ] Generally check what happens when we unbond-rebond the bell
    - [ ] Spawn closer to not-our beefalo than our beefalo
    - [ ] Dropping a bell into wormhole (may not trigger unhook because unload?)
    - [ ] Attacking a beefalo, defined but not tested


DONE
====
- [x] basic api `#bell_tracker`_
- [x] basic api `#beefalo_tracker`_
- [x] StartTask, CancelTask `#beefalo_tracker`_
- [x] Heat and Shaved `#beefalo_tracker`_
- [x] Wigfrid skills `#beefalo_tracker`_
- [x] basic ui `#ui`_
- [x] combined status integration and fancy riding display `#ui`_
- [x] event handling and timer/stat updating `#ui`_
- [x] check attacking beefalo `#beefalo_tracker`_
- [x] `TheSim:FindEntities` sometimes fails with `attempt to call a table value` `#bug`_
    - needed to wrap it in `ipairs()` %)
- [x] unhook player not triggering `#bug`_
    - `dropitem` isn't available on client, needed to redo a ton


.. _#ui: #ui
.. _#bell_tracker: #bell-tracker-component
.. _#beefalo_tracker: #beefalo-tracker-component

..
  vim: set nowrap ts=4 sw=4: