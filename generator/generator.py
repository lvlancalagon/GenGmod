import os
import shutil
import re
import json
import sys

def sanitize_name(s):
    return re.sub(r'[^a-z0-9_]', '', s.lower().replace(' ', '_'))

def normalize(s):
    return re.sub(r'[^a-z0-9]', '', s.lower())

def generate_nextbots():
    input_root = 'inputs'
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

    # Determine NPC sources: both folders and files in inputs/
    npc_sources = []

    if os.path.exists(input_root):
        # Check for subdirectories
        for d in sorted(os.listdir(input_root)):
            d_path = os.path.join(input_root, d)
            if os.path.isdir(d_path):
                npc_sources.append({'name': d, 'path': d_path, 'type': 'dir'})

        # Check for individual images in the root (legacy/simple mode)
        root_images = sorted([f for f in os.listdir(input_root) if os.path.isfile(os.path.join(input_root, f)) and f.lower().endswith(('.png', '.jpg', '.jpeg'))])
        for img in root_images:
            name = os.path.splitext(img)[0]
            # Skip if a folder with the same name already exists to avoid duplication
            if not any(s['name'] == name for s in npc_sources):
                npc_sources.append({'name': name, 'path': os.path.join(input_root, img), 'type': 'file'})

    if not npc_sources:
        print("No inputs found in inputs/. Please add images or folders.")
        return

    generated_count = 0

    for source in npc_sources:
        bot_display_name = source['name'].title()
        bot_name = sanitize_name(source['name'])
        normalized_name = normalize(source['name'])

        print(f"\nGenerating Nextbot: {bot_display_name} (from {source['type']} '{source['name']}')...")

        # Paths in GMod addon
        lua_path = os.path.join(addon_path, "lua", "entities", f"npc_{bot_name}.lua")
        material_dir = os.path.join(addon_path, "materials", "nextbot", bot_name)
        sound_dir = os.path.join(addon_path, "sound", "nextbot", bot_name)

        os.makedirs(os.path.dirname(lua_path), exist_ok=True)
        os.makedirs(material_dir, exist_ok=True)
        os.makedirs(sound_dir, exist_ok=True)

        images = []
        chase_sounds = []
        kill_sounds = []
        config = {
            "health": 100,
            "speed": 600,
            "acceleration": 4000,
            "search_radius": 2000,
            "lose_target_dist": 3000,
            "damage": 100,
            "jump_power": 58
        }

        if source['type'] == 'dir':
            # Gather from directory
            images = sorted([f for f in os.listdir(source['path']) if f.lower().endswith(('.png', '.jpg', '.jpeg'))])
            all_sounds = [f for f in os.listdir(source['path']) if f.lower().endswith(('.mp3', '.wav', '.ogg'))]
            for snd in all_sounds:
                snd_norm = normalize(os.path.splitext(snd.lower())[0])
                if any(x in snd_norm for x in ["kill", "death", "attack"]):
                    kill_sounds.append(os.path.join(source['path'], snd))
                else:
                    chase_sounds.append(os.path.join(source['path'], snd))

            config_file = os.path.join(source['path'], "config.json")
            if os.path.exists(config_file):
                try:
                    with open(config_file, 'r') as f:
                        config.update(json.load(f))
                except Exception as e: print(f"  Warning: Config error: {e}")
        else:
            # Gather from single file
            images = [os.path.basename(source['path'])]
            # Look for matching sounds in the root inputs/ folder
            root_sounds = [f for f in os.listdir(input_root) if os.path.isfile(os.path.join(input_root, f)) and f.lower().endswith(('.mp3', '.wav', '.ogg'))]
            for snd in root_sounds:
                snd_norm = normalize(os.path.splitext(snd.lower())[0])
                if normalized_name in snd_norm:
                    if any(x in snd_norm for x in ["kill", "death", "attack"]):
                        kill_sounds.append(os.path.join(input_root, snd))
                    else:
                        chase_sounds.append(os.path.join(input_root, snd))

        if not images:
            print(f"  Warning: No images found for {bot_display_name}. Skipping.")
            continue

        # Copy images
        material_paths = []
        for i, frame in enumerate(images):
            ext = os.path.splitext(frame)[1]
            dest_img_name = f"frame{i+1}{ext}"

            src_img_path = source['path'] if source['type'] == 'file' else os.path.join(source['path'], frame)

            shutil.copy(src_img_path, os.path.join(material_dir, dest_img_name))
            material_paths.append(f"nextbot/{bot_name}/{dest_img_name}")
            print(f"  Copied image: {os.path.basename(src_img_path)} -> {dest_img_name}")

        # Copy sounds
        chase_paths = []
        for i, snd_path in enumerate(chase_sounds):
            ext = os.path.splitext(snd_path)[1]
            dest = f"chase{i+1}{ext}"
            shutil.copy(snd_path, os.path.join(sound_dir, dest))
            chase_paths.append(f"nextbot/{bot_name}/{dest}")

        kill_paths = []
        for i, snd_path in enumerate(kill_sounds):
            ext = os.path.splitext(snd_path)[1]
            dest = f"kill{i+1}{ext}"
            shutil.copy(snd_path, os.path.join(sound_dir, dest))
            kill_paths.append(f"nextbot/{bot_name}/{dest}")

        # Template Replacements
        with open(template_path, 'r') as f: content = f.read()
        content = content.replace("{{PRINT_NAME}}", bot_display_name)
        content = content.replace("{{CHASE_SOUND}}", "{" + ", ".join([f'"{p}"' for p in chase_paths]) + "}")
        content = content.replace("{{KILL_SOUND}}", "{" + ", ".join([f'"{p}"' for p in kill_paths]) + "}")
        content = content.replace("{{MATERIAL_PATHS}}", "{" + ", ".join([f'"{p}"' for p in material_paths]) + "}")
        content = content.replace("{{CLASS_NAME}}", f"npc_{bot_name}")
        for k, v in config.items():
            content = content.replace("{{" + k.upper() + "}}", str(v))

        with open(lua_path, 'w') as f: f.write(content)
        generated_count += 1
        print(f"  Successfully generated NPC: {bot_display_name}")

    if generated_count > 0:
        addon_json_path = os.path.join(addon_path, "addon.json")
        addon_data = {
            "title": addon_name.replace('_', ' ').title(),
            "description": f"Generated using the Garry's Mod Nextbot Generator.",
            "type": "NPC", "tags": ["fun", "roleplay"], "ignore": []
        }
        with open(addon_json_path, 'w') as f: json.dump(addon_data, f, indent=4)

        print(f"\nSUCCESS: Generated {generated_count} Nextbots in: 'outputs/{addon_name}'")
        print("="*60)
        print("INSTALLATION:")
        print(f"1. Copy the folder 'outputs/{addon_name}' into your GMod 'addons' folder.")
        print("2. Ensure DrGBase is installed from the Steam Workshop.")
        print("="*60)

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    generate_nextbots()
