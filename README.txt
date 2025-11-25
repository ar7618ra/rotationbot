FROSTMOURNE ROTATION BOT
========================

This is a safe, pixel-based rotation helper for Warlock (Destruction).
It reads a color indicator from the addon and presses the corresponding key.

SETUP:
1. Copy the `FrostmourneRotation` folder to `Interface\AddOns\`.
   (It should already be there).
2. Launch WoW and enable the "FrostmourneRotation" addon.
3. You should see a small square at the TOP LEFT of your screen.
   - It will be BLACK when you have no target.
   - It will change colors when you target an enemy.

ACTION BAR SETUP (AFFLICTION):
Bind the following spells to these EXACT keys on your main bar:
[1] Haunt
[2] Unstable Affliction
[3] Corruption
[4] Curse of Agony
[5] Shadow Bolt
[6] Drain Soul
[7] Life Tap

RUNNING THE BOT:
1. Open a terminal/cmd.
2. Navigate to this folder.
3. Run: `python run_rotation.py`
4. Switch to the WoW window immediately.
5. Target an enemy and watch it cast!

TROUBLESHOOTING:
- If the bot doesn't cast, ensure the colored square is visible.
- If playing in Windowed Mode, ensure the window is at the top-left of your monitor, 
  or switch to "Windowed (Maximized)" / Fullscreen.
- The bot checks the pixel at screen coordinate (8, 8). Ensure the addon square covers this area.
