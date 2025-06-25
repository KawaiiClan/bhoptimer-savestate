# bhoptimer-SaveGame
- Allows the use of !savegame and !loadgame to save/load timer states between map changes and server restarts!
- Data is deleted as soon as it is loaded, so there is no way to exploit this as some sort of checkpoint system. It is the same usage as savestates, but now with even more persistence!

**Very early version, limited to admin commands currently. functionality is confirmed, but there are likely some bugs that need testing to find.**

### Installation
- Create an entry for "savegame" in `/addons/sourcemod/configs/databases.cfg`
- Load the plugin to create the database structure automatically

### Usage
- !savegame - Saves current progress in the map (writes timer state to db, and replay frames to `<replayfolder>/savedgames/<mapname>_<styleid>_<steamid>.replay`)
- !loadgame - Opens a menu with options to select which saved game you'd like to resume on the current map (you can save one per style per map)
