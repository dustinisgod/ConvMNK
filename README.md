version=1.0.0

# Convergence Monk Bot Command Guide

### Start Script
- Command: `/lua run ConvMNK`
- Description: Starts the Lua script Convergence Monk.

## General Bot Commands
These commands control general bot functionality, allowing you to start, stop, or save configurations.

### Toggle Bot On/Off
- Command: `/ConvMNK Bot on/off`
- Description: Enables or disables the bot for automated functions.

### Save Settings
- Command: `/ConvMNK Save`
- Description: Saves the current settings, preserving any configuration changes.

---

### Set Assist Parameters
- Command: `/ConvMNK Assist <name> <range> <percent>`
- Description: Sets the main assist name, assist range, and assist health percentage.

---

## Camp and Navigation
These commands control camping behavior and movement options.

### Set Camp Location
- Command: `/ConvMNK CampHere`
- Description: Sets the current location as the designated camp location.

### Set Camp Distance
- Command: `/ConvMNK CampDistance <distance>`
- Description: Defines the maximum distance from the camp location.
- Usage: `/ConvMNK CampDistance 100` sets a 100-unit radius.

### Return to Camp
- Command: `/ConvMNK Return on/off`
- Description: Enables or disables automatic return to camp if moving too far.

### Toggle Chase Mode
- Command: `/ConvMNK Chase <target> <distance>` or `/ConvMNK Chase on/off`
- Description: Sets a target and distance for the bot to chase, or toggles chase mode.
- Example: `/ConvMNK Chase John 30` will set the character John as the chase target at a distance of 30.
- Example: `/ConvMNK Chase off` will turn chasing off.

---

## Combat and Assist Commands
These commands control combat behaviors, including melee assistance and target positioning.

### Set Assist Melee
- Command: `/ConvMNK AssistMelee on/off`
- Description: Enables or disables melee assistance.

### Toggle Stick Position (Front)
- Command: `/ConvMNK StickFront on/off`
- Description: Sets the bot to stick to the front of the target.

### Toggle Stick Position (Back)
- Command: `/ConvMNK StickBack on/off`
- Description: Sets the bot to stick to the back of the target.

### Stick Distance
- Command: `/ConvMNK StickDistance <distance>`
- Description: Sets the distance to stick to a target.

---

### Toggle Pulling
- Command: `/ConvMNK Pull on/off`
- Description: Enables or disables pulling behavior.

### Pull Pause
- Command: `/ConvMNK PullPause on/off`
- Description: Pauses or resumes pulling.

## Pulling and Mob Control
These commands manage mob pulling, setting levels, distances, and mob retention in the camp area.

### Pull Amount
- Command: `/ConvMNK PullAmount <amount>`
- Description: Defines the number of mobs to pull.

### Pull Distance
- Command: `/ConvMNK PullDistance <distance>`
- Description: Sets the maximum distance to pull mobs.

### Pull Level Min/Max
- Command: `/ConvMNK PullLevelMin <level>` and `/ConvMNK PullLevelMax <level>`
- Description: Specifies the minimum and maximum levels of mobs to pull.

### Pull Pause Timer
- Command: `/ConvMNK PullPauseTimer <timer>`
- Description: Sets the pull pause timer duration.

### Keep Mobs In Camp Amount
- Command: `/ConvMNK KeepMobsInCampAmount <amount>`
- Description: Sets the number of mobs allowed within the camp radius.

### Toggle Keep Mobs In Camp
- Command: `/ConvMNK KeepMobsInCamp on/off`
- Description: Enables or disables keeping mobs within the camp area.

---

## Additional Commands

### Toggle Feign Death
- Command: `/ConvMNK Feign <percent>` or `/ConvMNK Feign off`
- Description: Enables or disables feign death on aggro percent.

### Toggle Mend
- Command: `/ConvMNK Mend <percent>` or `/ConvMNK Mend off`
- Description: Enables or disables mend at health percent.