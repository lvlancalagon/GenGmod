# Garry's Mod 2D Animated Nextbot Generator (DrGBase)

This tool automates the creation of high-quality, aggressive, and animated 2D Nextbots for Garry's Mod using the **DrGBase** framework.

## Requirements
- Python 3
- [DrGBase (Workshop ID 1560118657)](https://steamcommunity.com/sharedfiles/filedetails/?id=1560118657)

## Usage

1. **Organize Inputs:**
   Create a folder inside `inputs/` for each NPC you want to generate.
   - **Name the folder** exactly how you want the NPC to be named (e.g., `Aggressive Sanic`).
   - **Images:** Place one or more images (.png, .jpg) in the folder. If you provide multiple, they will automatically animate in-game.
   - **Sounds:** Place audio files (.mp3, .wav, .ogg). Files containing "kill", "death", or "attack" in the name will be used as kill sounds. All others will be chase/idle sounds.
   - **(Optional) config.json:** Place a `config.json` inside the NPC's folder to override stats:
     ```json
     {
       "health": 500,
       "speed": 800,
       "damage": 50
     }
     ```

2. **Generate:**
   Run the generator from the root directory:
   ```bash
   python3 generator/generator.py MyAddonName
   ```
   (Replace `MyAddonName` with the label you want for your GMod addon folder).

3. **Install:**
   Copy the generated folder from `outputs/MyAddonName` into your Garry's Mod `addons/` directory.

## Features
- **DrGBase AI:** Superior pathfinding and navigation.
- **Auto-Animation:** Frames are automatically detected and cycled.
- **Aggressive Behavior:** Smashes physics props and deals damage on contact.
- **Automatic Organization:** Labeled folders and sanitized internal naming.
- **Troubleshooting:** Included guide for common Steam Workshop errors.
