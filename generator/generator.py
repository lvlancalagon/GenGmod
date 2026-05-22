import os
import shutil
import re
import json
import sys

def normalize(s):
    # Normalize by lowercasing and removing all non-alphanumeric characters
    return re.sub(r'[^a-z0-9]', '', s.lower())

def generate_nextbots():
    input_dir = 'inputs'
    output_dir = 'outputs'
    template_path = 'template.lua'

    # Allow custom addon name via environment or CLI
    addon_name = os.getenv("ADDON_NAME", "my_generated_addon")
    if len(sys.argv) > 1:
        addon_name = sys.argv[1]

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
    all_images = [f for f in os.listdir(input_dir) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]

    # Determine primary images (those that aren't secondary animation frames)
    # A primary image is either the only image, or doesn't end with _2, _frame2, etc.
    primary_images = []
    for img in all_images:
        img_base = os.path.splitext(img.lower())[0]
        if not re.search(r'(_[2-9]|_frame[2-9])$', img_base):
            primary_images.append(img)

    # Find all sounds (MP3/WAV/OGG)
    all_sounds = [f for f in os.listdir(input_dir) if f.lower().endswith(('.mp3', '.wav', '.ogg'))]

    generated_count = 0

    for img_file in primary_images:
        img_base = os.path.splitext(img_file)[0]
        # bot_name is the sanitized version for GMod class naming
        bot_name = re.sub(r'[^a-z0-9_]', '', img_base.lower().replace(' ', '_'))
        # normalized_name is for matching assets regardless of spaces/underscores
        normalized_name = normalize(img_base)

        print(f"\nGenerating Nextbot: {bot_name} (from {img_file})...")

        # Paths in GMod addon
        lua_path = os.path.join(addon_path, "lua", "entities", f"npc_{bot_name}.lua")
        material_dir = os.path.join(addon_path, "materials", "nextbot", bot_name)
        sound_dir = os.path.join(addon_path, "sound", "nextbot", bot_name)

        os.makedirs(os.path.dirname(lua_path), exist_ok=True)
        os.makedirs(material_dir, exist_ok=True)
        os.makedirs(sound_dir, exist_ok=True)

        # Find secondary animation frames
        animation_frames = [img_file]
        for other_img in all_images:
            if other_img == img_file: continue
            other_base = os.path.splitext(other_img.lower())[0]
            if normalized_name in normalize(other_base) and re.search(r'(_[2-9]|_frame[2-9])$', other_base):
                animation_frames.append(other_img)
                print(f"  Found animation frame: {other_img}")

        # Assets
        chase_sounds = []
        kill_sounds = []

        # Look for sounds
        for snd in all_sounds:
            snd_clean = os.path.splitext(snd.lower())[0]
            snd_norm = normalize(snd_clean)

            if normalized_name in snd_norm or len(primary_images) == 1:
                if any(x in snd_norm for x in ["kill", "death", "attack"]):
                    kill_sounds.append(snd)
                else:
                    chase_sounds.append(snd)

        # Copy images
        material_paths = []
        for i, frame in enumerate(animation_frames):
            ext = os.path.splitext(frame)[1]
            dest_img_name = f"frame{i+1}{ext}"
            shutil.copy(os.path.join(input_dir, frame), os.path.join(material_dir, dest_img_name))
            material_paths.append(f"nextbot/{bot_name}/{dest_img_name}")

        # Prepare Lua material list
        mat_lua_table = "{" + ", ".join([f'"{p}"' for p in material_paths]) + "}"

        # Copy sounds and prepare Lua table strings
        chase_sound_paths = []
        for i, snd in enumerate(chase_sounds):
            ext = os.path.splitext(snd)[1]
            dest_name = f"chase{i+1}{ext}"
            shutil.copy(os.path.join(input_dir, snd), os.path.join(sound_dir, dest_name))
            chase_sound_paths.append(f"nextbot/{bot_name}/{dest_name}")
            print(f"  Matched chase sound: {snd} -> {dest_name}")

        kill_sound_paths = []
        for i, snd in enumerate(kill_sounds):
            ext = os.path.splitext(snd)[1]
            dest_name = f"kill{i+1}{ext}"
            shutil.copy(os.path.join(input_dir, snd), os.path.join(sound_dir, dest_name))
            kill_sound_paths.append(f"nextbot/{bot_name}/{dest_name}")
            print(f"  Matched kill sound: {snd} -> {dest_name}")

        chase_lua_table = "{" + ", ".join([f'"{p}"' for p in chase_sound_paths]) + "}"
        kill_lua_table = "{" + ", ".join([f'"{p}"' for p in kill_sound_paths]) + "}"

        # Load optional config
        config_file = os.path.join(input_dir, f"{bot_name}.json")
        bot_config = {
            "health": 100,
            "speed": 600,
            "acceleration": 4000,
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
        content = content.replace("{{MATERIAL_PATHS}}", mat_lua_table)
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
            "title": addon_name.replace('_', ' ').title(),
            "description": f"A collection of aggressive 2D Nextbots labeled under '{addon_name}'.",
            "type": "NPC",
            "tags": ["fun", "roleplay"],
            "ignore": []
        }
        with open(addon_json_path, 'w') as f:
            json.dump(addon_data, f, indent=4)

        # Create local README.txt in the addon folder
        readme_content = f"""
Garry's Mod Generated Nextbot Addon: {addon_name}
===================================

This addon was automatically generated and requires DrGBase.

Installation:
1. Ensure you have DrGBase installed: https://steamcommunity.com/sharedfiles/filedetails/?id=1560118657
2. Copy this folder ('{addon_name}') into your 'Garry's Mod/garrysmod/addons/' directory.
   - IMPORTANT: Make sure the 'lua', 'materials', and 'sound' folders are all inside.
3. Restart Garry's Mod.

Troubleshooting:
- If you see 'Addon Hidden addon failed to download' in the console:
  This is a Steam Workshop issue. It means you are subscribed to a workshop item
  that has been deleted or hidden by its author. It is NOT caused by this local addon.
  To fix it, go to your Steam Workshop subscriptions and unsubscribe from any items
  that appear as 'Deleted' or 'Hidden'.

- If the Nextbot doesn't appear in-game:
  Check the 'NPCs' tab in the spawn menu under the category 'Custom Nextbots'.
"""
        with open(os.path.join(addon_path, "README.txt"), 'w') as f:
            f.write(readme_content.strip())
        print(f"\nSuccessfully generated {generated_count} Nextbots in labeled folder: '{addon_name}'")

        # Troubleshooting Info
        print("\n" + "="*50)
        print("TROUBLESHOOTING & INSTALLATION")
        print("="*50)
        print(f"1. Ensure DrGBase is installed: https://steamcommunity.com/sharedfiles/filedetails/?id=1560118657")
        print(f"2. Copy the folder 'outputs/{addon_name}' to your GMod 'addons' directory.")
        print("3. If you see 'Addon Hidden addon failed to download' in GMod, please note:")
        print("   - This is a known Steam Workshop issue and is NOT caused by this generator.")
        print("   - It happens when you are subscribed to an addon that was deleted or hidden by its creator.")
        print("   - To fix it, go to your Steam Workshop subscriptions and unsubscribe from any 'Deleted' or 'Hidden' items.")
        print("4. Ensure your 'inputs' folder has valid .png and .mp3/.wav files for the best results.")
        print("="*50 + "\n")

if __name__ == "__main__":
    # Change directory to the script's directory to handle relative paths correctly
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    generate_nextbots()
