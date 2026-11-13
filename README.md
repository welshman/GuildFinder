# Guild Finder

Guild Finder is a recruitment board built only for WoW Forever. Guilds post adverts to recruit, players post "looking for guild" adverts, and both sides can browse, filter and contact each other by whisper.

It does not replace the game's own tools, and it never sends anything for you. Every whisper opens pre-filled in your chat box and you press Enter yourself.

## Please read first

*   **AI was used to help make this addon.** The code was written with the help of an AI assistant and reviewed and put together by the author.
*   **It has not been fully tested.** Bugs are likely, especially in the first versions. Parts of it, such as syncing between users and reading chat posts, have had very little testing in the live game.
*   **Please report problems.** Open a ticket on the Issues tab and include the exact error text (see Support below). Every report helps.
*   **Fixes and improvements are welcome.** The source code is on GitHub, linked in the Source section of this page. If you can fix a bug or add a feature, please open a pull request or an issue there.

## Features

**Find a Guild** (for players)

*   Browse guild adverts from your own faction and ruleset
*   Filter by guild type, role, raid, level stage, class, level, days, times, timezone, guild size and keywords
*   Search names, descriptions and class notes
*   See open tank, healer and DPS spots at a glance
*   A ready-made application message that fills in your class, spec, role, level and availability. Edit it before sending

**Find Members** (for guild officers and recruiters)

*   Browse player adverts with role, class, level, experience and schedule
*   A ready-made invite message that fills in your guild details
*   Open the whisper with one click

**Built for Forever**

*   Level cap 60 and Forever's three raids: Barrow Deeps (10), Hyjal Summit (20) and Onyxia's Lair (40)
*   Faction and ruleset are detected automatically. You only see listings you could actually play with
*   No realm fields, no item level, no Mythic+

**Your adverts**

*   Create, edit, pause, renew and delete your own guild and player adverts
*   One-line chat advert you can copy and paste into General or Trade yourself
*   Expiry reminders, and optional auto-renew on login
*   Fill in your guild's name and contact with one click

**Keep track**

*   Favourites, a Contacted list and private notes, all saved only on your computer
*   One alert (and a minimap pulse) when new matching listings arrive
*   Hide a listing or block an author at any time

**Sharing between users**

*   Adverts are shared with other Guild Finder users through a private addon channel
*   Listings are validated, rate limited and can only be edited or deleted by their author
*   Everything also works with no one else online. Your own adverts, saved lists and filters are local
*   Optional: read guild recruitment posts from General and Trade chat. This is off by default, the results are marked "From chat", and they are never shared

## Getting started

1.  Install and enable the addon
2.  Type /gfinder or click the minimap button
3.  Open Find a Guild or Find Members, or create your advert under My adverts
4.  Select a listing, edit the message if you want, and click Whisper

## Commands

*   /gfinder, /gfboard or /glf: open the window
*   /gfinder settings, refresh, renew, status, channel, rejoin, debug, reset
*   /gfmap: show or hide the minimap button

(/gf and /guildfinder are used by the game itself, so Guild Finder does not use them.)

## Good to know

*   You will only see other players' adverts once other people on your faction and ruleset use Guild Finder. Share the addon with your guild
*   Syncing depends on the game allowing addon messages on a private channel. If the client restricts this, adverts still work locally and you can swap them with Settings > Export / Import. Run /gfinder channel to test it
*   Adverts expire after 7 days by default (1 to 30 days in Settings)
*   Whispers are never sent automatically. Nothing is posted to chat channels for you

## Support and bug reports

Found a bug? Please open a ticket on the Issues tab, or on GitHub, and include:

1.  What you were doing and what you expected to happen
2.  The exact error text. Type /console scriptErrors 1, then /reload, and copy the red error popup
3.  The output of /gfinder status and /gfinder debug log

## Contributing

Guild Finder is open source under the MIT licence. The GitHub link is in the Source section of this page. Bug fixes, tidy-ups, translations and new ideas are all welcome. If you'd rather not write code, a clear bug report or suggestion is just as useful.

## Licence
MIT
