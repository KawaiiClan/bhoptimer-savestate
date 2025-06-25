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

### Screenshots
- Saving and loading messages
<br>![image](https://github.com/user-attachments/assets/89b272cd-5341-4a52-937c-b367ca82ef23)

- It will let you know if you have a save on the current map on your first spawn
<br>![image](https://github.com/user-attachments/assets/dc149910-caf0-4a4f-a65d-65ca59f86e73)

- !loadgame menu
<br>![image](https://github.com/user-attachments/assets/d37e7a4e-e36c-4ccb-af66-843a74b11283)
