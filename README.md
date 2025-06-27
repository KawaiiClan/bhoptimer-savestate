# bhoptimer-savestate
## Allows the use of !savestate to save/load [bhoptimer](https://github.com/shavitush/bhoptimer) timer states between map changes and server restarts!

**Very early version, functionality has been confirmed with no current bugs/exploits found, but more testing is needed. Please open a PR or let me know of any issues, ty!**
- Players may have one savestate on each style per map
- When a player saves a savestate, their timer state and replay frames are saved in the database and replay file folder respectively. Their timer is stopped (to prevent checkpoint-like usage), and they can continue to play on the server like normal.
- It is currently (and probably always will be) limited to the `Main` track only. There aren't really any bonuses that would warrant this functionality, and it just opens up more possibilities for bloat files.

### Note
If you run multiple servers from the same directory (ie. public and private servers), and they share a savestate db, you can load saves between them seamlessly!

## Installation
- Create an entry for "savegame" in `/addons/sourcemod/configs/databases.cfg`
- Load the plugin to create the database structure automatically (only one `saves` table, many columns)

## ConVars
- `shavit_savestate_savereplayoverwr` (0 / 1) - Whether or not to save replay frames if player's time is longer than the WR (useful with things like !myreplay)

## Usage
- !savestate - Opens a menu to save/load a savestate, or view all savestates. (Writes timer state to db, and replay frames to `<replayfolder>/savedgames/<mapname>_<styleid>_<steamid>.replay`) if a save exists for the player on the current map and style, a confirmation to overwrite the current save will appear.

## Screenshots
- Main menu
<br>![Screenshot from 2025-06-27 12-20-10](https://github.com/user-attachments/assets/032c0baf-20de-428b-aad1-97145bd24e94)


- It will let you know if you have a save on the current map on your first spawn (or first restart, post-saving)
<br>![image](https://github.com/user-attachments/assets/becbbd01-2600-47dc-8488-46f3e24c056d)


- Load menu
<br>![Screenshot from 2025-06-27 12-22-59](https://github.com/user-attachments/assets/7b62ebc3-c802-4bab-a353-88e5197ad2b6)


- All saves menu
<br>![Screenshot from 2025-06-27 12-23-20](https://github.com/user-attachments/assets/d8c3867c-ec6a-4dc2-88e3-fc1fe70dbe5c)

- Overwrite confirmation
<br>![Screenshot from 2025-06-27 12-23-32](https://github.com/user-attachments/assets/d9a16c76-3514-4574-ae3c-e45a18288bd0)

## TODO
- Add the ability to delete saved games without loading them
- Maybe add checkpoint saving, instead of clearing. They are cleared because there were exploits that could be done with doing !savegame, saving checkpoints, then !loadgame.. maybe SetCurrentCheckpoint or forcing checkpoint deletions will be the fix.. but having checkpoints save between loads seems like a marginal use that may not be worth the risk/effort anyway
