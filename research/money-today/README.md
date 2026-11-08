# How much money the game earns today: measurement scripts

Throwaway branch for the wayfinder ticket "How much money the game earns today" (#92). Never merged.

Run from the repo root with Godot 4.7.2:

- `Godot --headless --path . -s research/money-today/offers.gd`: offer rewards per location/kind, fit per ship type, best mission from a fresh 6-offer pool. Output: `offers.txt`.
- `Godot --headless --fixed-fps 60 --path . -s research/money-today/flights.gd`: an autopilot (`pilot.gd`, pressing the real input actions) flies station → pad loaded and pad → dock empty in the real scene, for every ship type, location and load. Output: `flights.txt`.
- `Godot --headless --fixed-fps 60 --path . -s research/money-today/heavy.gd`: heavy loads under several descent profiles (Valley). Output: `heavy.txt`.
- `Godot --headless --path . -s research/money-today/income.gd`: a 200-hour event simulation of the real offer pool (arrivals, expiry) with missions flown back to back, cycle times from `flights.txt`. Output: `income.txt`.
