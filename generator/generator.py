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
    npc_list = []

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
            # Matches: botname, botname_chase, botname_sound, botname_chase1, botname1, etc.
            chase_patterns = [
                re.compile(rf'^{bot_name}(_chase|_sound)?(\d+)?$'),
            ]
            if any(p.match(snd_clean) for p in chase_patterns):
                chase_sounds.append(snd)

            # Kill sound candidates
            # Matches: botname_kill, botname_death, botname_death_sound, botname_kill1, etc.
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

        npc_list.append({
            "name": bot_display_name,
            "class": f"npc_{bot_name}",
            "category": "Nextbot Generator"
        })

        generated_count += 1
        print(f"Done for {bot_name}!")

    if generated_count > 0:
        # Create autorun file for NPC registration
        autorun_dir = os.path.join(addon_path, "lua", "autorun")
        os.makedirs(autorun_dir, exist_ok=True)
        autorun_path = os.path.join(autorun_dir, "generated_nextbots_reg.lua")

        with open(autorun_path, 'w') as f:
            f.write("-- NPC Registration for Generated Nextbots\n")
            for npc in npc_list:
                f.write(f'list.Set("NPC", "{npc["class"]}", {{\n')
                f.write(f'    Name = "{npc["name"]}",\n')
                f.write(f'    Class = "{npc["class"]}",\n')
                f.write(f'    Category = "{npc["category"]}",\n')
                f.write(f'    AdminSpawnable = true,\n')
                f.write(f'    Spawnable = true\n')
                f.write(f'}})\n\n')

        # Create addon.json
        addon_json_path = os.path.join(addon_path, "addon.json")
        addon_data = {
            "title": "Generated Nextbots Collection",
            "type": "npc",
            "tags": ["fun", "roleplay"],
            "ignore": []
        }
        with open(addon_json_path, 'w') as f:
            json.dump(addon_data, f, indent=4)
        print(f"\nSuccessfully generated {generated_count} Nextbots in '{addon_name}'")

if __name__ == "__main__":
    # Change directory to the script's directory to handle relative paths correctly
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    generate_nextbots()
