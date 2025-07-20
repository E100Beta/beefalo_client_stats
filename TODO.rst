====================
Beefalo Client Stats
====================
Makes best effort guesses about your beefalo current stats
for easier domestication and ornery obedience management.

EPICS
=====
- [x] _`UI`
- [x] _`Beefalo Tracker Component`
- [x] _`Bell Tracker Component`
    - removed, lmao


TODO
====
- [ ] salt lick pausing domestication `#beefalo_tracker`_
    - [ ] probably on unhook
    - A way to cancel it if we see another player on our beefalo?
- [ ] bring back active item tracking to also check animation for feeding

IN PROGRESS
===========


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
- [x] OnSave, OnLoad `#beefalo_tracker`_
    - need to do after everything when I'm sure core concept is fine
- [x] thread to wait on next animation until idle `#beefalo_tracker`_
    - we need a way to check for vomiting/farting, maybe even begging?
    - I think we should do like an animation watcher that's constantly running, that'll be much easier
- [x] Probably need to also not save if it's just default stats?
- [x] Add interface appearing on bonding, it's too much of a friction point.
- [x] Check for unbounding a beefalo
- [x] Add UI settings, adjust for 1080 as base.
- [x] Test cases:
    - [x] Generally check what happens when we unbond-rebond the bell - seems like nothing
    - [x] Spawn closer to not-our beefalo than our beefalo
    - [x] Dropping a bell into wormhole (may not trigger unhook because unload?)
    - [x] Check conditions for OnSave and OnRemoveFromEntity
    - [x] Load after rollback, will probably need to detect that - WONTFIX
    - [x] Picking up bonded bell of dead beefalo
    - [x] Giving to wormholes doesn't work. On giving rescan if held by.


.. _#ui: #ui
.. _#bell_tracker: #bell-tracker-component
.. _#beefalo_tracker: #beefalo-tracker-component

..
  vim: set nowrap ts=4 sw=4: