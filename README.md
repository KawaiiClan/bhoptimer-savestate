# bhoptimer-SaveGame
## Allows the use of !savegame and !loadgame to save/load [bhoptimer](https://github.com/shavitush/bhoptimer) savestates between map changes and server restarts!

**Very early version, commands are limited to admins currently. Functionality has been confirmed with no current bugs/exploits found, but more testing is needed before public use. Please open a PR or let me know of any issues, ty!**

- When a player uses `!savegame`, their timer state and replay frames are saved in the database and replay file folder respectively. Their timer is stopped (to prevent checkpoint-like usage), and they can continue to play on the server like normal.
- When a player uses `!loadgame`, they can choose which save to load. The data is loaded then deleted, so there is no way to exploit this and restore a state multiple times. It is the same functionality as the built in savestates, but now with more persistence!
- It is currently (and probably always will be) limited to the `Main` track only. There aren't really any bonuses that would warrant this functionality, and it just opens up more possibilities for bloat files.

### Installation
- Create an entry for "savegame" in `/addons/sourcemod/configs/databases.cfg`
- Load the plugin to create the database structure automatically (only one `saves` table, many columns)

### Usage
- !savegame - Saves current progress in the map (Writes timer state to db, and replay frames to `<replayfolder>/savedgames/<mapname>_<styleid>_<steamid>.replay`) if a save exists for the player on the current map and style, a confirmation to overwrite the current save will appear.
- !loadgame - Opens a menu with options to select which saved game you'd like to resume on the current map (Players can save one per style per map)

### Screenshots
- Saving and loading messages
<br>![image](https://github.com/user-attachments/assets/89b272cd-5341-4a52-937c-b367ca82ef23)

- It will let you know if you have a save on the current map on your first spawn
<br>![image](https://github.com/user-attachments/assets/dc149910-caf0-4a4f-a65d-65ca59f86e73)

- !loadgame menu
<br>![image](https://github.com/user-attachments/assets/d37e7a4e-e36c-4ccb-af66-843a74b11283)

### TODO
- Add the ability to delete saved games without loading them
- Add a command to see all of the maps you have a saved game on
- Show the time in the `!loadgame` menu (as well as the other menus in TODO)
- Maybe add checkpoint saving, instead of clearing. They are cleared because there were exploits that could be done with doing !savegame, saving checkpoints, then !loadgame.. maybe SetCurrentCheckpoint or forcing checkpoint deletions will be the fix.. but having checkpoints save between loads seems like a marginal use that may not be worth the risk anyway
