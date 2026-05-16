import os
import shutil
import re
import json

def generate_nextbots():
    input_dir = 'inputs'
    output_dir = 'outputs'
    template_path = 'template.lua'
    addon_name = "generated_nextbots"

    if not os.path.exists(template_path):
        print(f"Error: {template_path} not found.")
        return

    # Ensure output directory exists and is clean
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)

    addon_path = os.path.join(output_dir, addon_name)
    os.makedirs(addon_path)

    # Find all images (PNG/JPG)
    images = [f for f in os.listdir(input_dir) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]

    generated_count = 0

    for img_file in images:
        bot_name = os.path.splitext(img_file)[0].lower()
        bot_name = re.sub(r'[^a-z0-9_]', '', bot_name) # Sanitize for GMod

        print(f"Generating Nextbot: {bot_name}...")

        # Paths in GMod addon
        lua_path = os.path.join(addon_path, "lua", "entities", f"npc_{bot_name}.lua")
        material_dir = os.path.join(addon_path, "materials", "nextbot")
        sound_dir = os.path.join(addon_path, "sound", "nextbot", bot_name)

        os.makedirs(os.path.dirname(lua_path), exist_ok=True)
        os.makedirs(material_dir, exist_ok=True)
        os.makedirs(sound_dir, exist_ok=True)

        # Assets
        chase_sounds = []
        kill_sounds = []

        # Look for sounds
        for snd in os.listdir(input_dir):
            snd_lower = snd.lower()
            if not snd_lower.endswith(('.mp3', '.wav')):
                continue

            snd_clean = os.path.splitext(snd_lower)[0]

            # Chase sound candidates
            chase_patterns = [
                re.compile(rf'^{bot_name}(_chase|_sound)?(\d+)?$'),
            ]
            if any(p.match(snd_clean) for p in chase_patterns):
                chase_sounds.append(snd)

            # Kill sound candidates
            kill_patterns = [
                re.compile(rf'^{bot_name}(_kill|_death|_death_sound)(\d+)?$'),
            ]
            if any(p.match(snd_clean) for p in kill_patterns):
                kill_sounds.append(snd)

        # Copy image
        shutil.copy(os.path.join(input_dir, img_file), os.path.join(material_dir, img_file))
        material_path = f"nextbot/{img_file}"

        # Copy sounds and prepare Lua table strings
        chase_sound_paths = []
        for i, snd in enumerate(chase_sounds):
            ext = os.path.splitext(snd)[1]
            dest_name = f"chase{i+1}{ext}"
            shutil.copy(os.path.join(input_dir, snd), os.path.join(sound_dir, dest_name))
            chase_sound_paths.append(f"nextbot/{bot_name}/{dest_name}")

        kill_sound_paths = []
        for i, snd in enumerate(kill_sounds):
            ext = os.path.splitext(snd)[1]
            dest_name = f"kill{i+1}{ext}"
            shutil.copy(os.path.join(input_dir, snd), os.path.join(sound_dir, dest_name))
            kill_sound_paths.append(f"nextbot/{bot_name}/{dest_name}")

        chase_lua_table = "{" + ", ".join([f'"{p}"' for p in chase_sound_paths]) + "}"
        kill_lua_table = "{" + ", ".join([f'"{p}"' for p in kill_sound_paths]) + "}"

        # Load optional config
        config_file = os.path.join(input_dir, f"{bot_name}.json")
        bot_config = {
            "health": 100,
            "speed": 450,
            "acceleration": 900,
            "search_radius": 2000,
            "lose_target_dist": 3000,
            "damage": 100,
            "jump_power": 58
        }
        if os.path.exists(config_file):
            try:
                with open(config_file, 'r') as f:
                    user_config = json.load(f)
                    bot_config.update(user_config)
            except Exception as e:
                print(f"Warning: Failed to load config for {bot_name}: {e}")

        # Read template and replace
        with open(template_path, 'r') as f:
            content = f.read()

        bot_display_name = bot_name.replace('_', ' ').title()
        content = content.replace("{{PRINT_NAME}}", bot_display_name)
        content = content.replace("{{CHASE_SOUND}}", chase_lua_table)
        content = content.replace("{{KILL_SOUND}}", kill_lua_table)
        content = content.replace("{{MATERIAL_PATH}}", material_path)
        content = content.replace("{{CLASS_NAME}}", f"npc_{bot_name}")
        content = content.replace("{{HEALTH}}", str(bot_config["health"]))
        content = content.replace("{{SPEED}}", str(bot_config["speed"]))
        content = content.replace("{{ACCELERATION}}", str(bot_config["acceleration"]))
        content = content.replace("{{SEARCH_RADIUS}}", str(bot_config["search_radius"]))
        content = content.replace("{{LOSE_TARGET_DIST}}", str(bot_config["lose_target_dist"]))
        content = content.replace("{{DAMAGE}}", str(bot_config["damage"]))
        content = content.replace("{{JUMP_POWER}}", str(bot_config["jump_power"]))

        with open(lua_path, 'w') as f:
            f.write(content)

        generated_count += 1
        print(f"Done for {bot_name}!")

    if generated_count > 0:
        # Create addon.json
        addon_json_path = os.path.join(addon_path, "addon.json")
        addon_data = {
            "title": "Generated Nextbots Collection",
            "description": "A collection of 2D Nextbots generated using the Garry's Mod Nextbot Generator.",
            "type": "NPC",
            "tags": ["fun", "roleplay"],
            "ignore": []
        }
        with open(addon_json_path, 'w') as f:
            json.dump(addon_data, f, indent=4)

        # Create local README.txt in the addon folder
        readme_content = f"""
Garry's Mod Generated Nextbot Addon
===================================

This addon was automatically generated.

Installation:
1. Copy this folder ('{addon_name}') into your 'Garry's Mod/garrysmod/addons/' directory.
2. Restart Garry's Mod.

Troubleshooting:
- If you see 'Addon Hidden addon failed to download' in the console:
  This is a Steam Workshop issue. It means you are subscribed to a workshop item
  that has been deleted or hidden by its author. It is NOT caused by this local addon.
  To fix it, go to your Steam Workshop subscriptions and unsubscribe from any items
  that appear as 'Deleted' or 'Hidden'.

- If the Nextbot doesn't appear in-game:
  Check the 'NPCs' tab in the spawn menu under the category 'Nextbot Generator'.
"""
        with open(os.path.join(addon_path, "README.txt"), 'w') as f:
            f.write(readme_content.strip())
        print(f"\nSuccessfully generated {generated_count} Nextbots in '{addon_name}'")

        # Troubleshooting Info
        print("\n" + "="*50)
        print("TROUBLESHOOTING & INSTALLATION")
        print("="*50)
        print(f"1. Copy the folder 'outputs/{addon_name}' to your GMod 'addons' directory.")
        print("2. If you see 'Addon Hidden addon failed to download' in GMod, please note:")
        print("   - This is a known Steam Workshop issue and is NOT caused by this generator.")
        print("   - It happens when you are subscribed to an addon that was deleted or hidden by its creator.")
        print("   - To fix it, go to your Steam Workshop subscriptions and unsubscribe from any 'Deleted' or 'Hidden' items.")
        print("3. Ensure your 'inputs' folder has valid .png and .mp3/.wav files for the best results.")
        print("="*50 + "\n")

if __name__ == "__main__":
    # Change directory to the script's directory to handle relative paths correctly
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    generate_nextbots()
