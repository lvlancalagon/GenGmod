import os
import shutil
import re
import json
import sys

def sanitize(s):
    return re.sub(r'[^a-z0-9_]', '', s.lower().replace(' ', '_'))

def normalize(s):
    return re.sub(r'[^a-z0-9]', '', s.lower())

def generate_nextbots():
    input_root = 'inputs'
    output_dir = 'outputs'
    template_path = 'template.lua'

    addon_name = sys.argv[1] if len(sys.argv) > 1 else os.getenv("ADDON_NAME", "my_generated_pack")

    if not os.path.exists(template_path):
        print(f"ERROR: {template_path} not found.")
        return

    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)

    addon_path = os.path.join(output_dir, addon_name)
    os.makedirs(addon_path)

    npc_sources = []
    if os.path.exists(input_root):
        # 1. Folders
        for d in sorted(os.listdir(input_root)):
            d_path = os.path.join(input_root, d)
            if os.path.isdir(d_path):
                npc_sources.append({'name': d, 'path': d_path, 'type': 'dir'})

        # 2. Loose files in root
        root_images = sorted([f for f in os.listdir(input_root) if os.path.isfile(os.path.join(input_root, f)) and f.lower().endswith(('.png', '.jpg', '.jpeg'))])
        for img in root_images:
            name = os.path.splitext(img)[0]
            if not any(s['name'] == name for s in npc_sources):
                npc_sources.append({'name': name, 'path': os.path.join(input_root, img), 'type': 'file'})

    if not npc_sources:
        print("ERROR: No assets found in inputs/.")
        return

    generated_count = 0

    for source in npc_sources:
        bot_disp = source['name'].title()
        bot_name = sanitize(source['name'])
        bot_norm = normalize(source['name'])

        print(f"\n[+] Building NPC: {bot_disp}")

        lua_path = os.path.join(addon_path, "lua", "entities", f"npc_{bot_name}.lua")
        mat_dir = os.path.join(addon_path, "materials", "nextbot", bot_name)
        snd_dir = os.path.join(addon_path, "sound", "nextbot", bot_name)

        os.makedirs(os.path.dirname(lua_path), exist_ok=True)
        os.makedirs(mat_dir, exist_ok=True)
        os.makedirs(snd_dir, exist_ok=True)

        frames = []
        chase_src = []
        kill_src = []
        config = {
            "health": 100, "speed": 600, "acceleration": 4000,
            "search_radius": 2000, "lose_target_dist": 3000,
            "damage": 100, "jump_power": 58
        }

        if source['type'] == 'dir':
            frames = sorted([f for f in os.listdir(source['path']) if f.lower().endswith(('.png', '.jpg', '.jpeg'))])
            all_s = [f for f in os.listdir(source['path']) if f.lower().endswith(('.mp3', '.wav', '.ogg'))]
            for s in all_s:
                s_n = normalize(os.path.splitext(s.lower())[0])
                if any(x in s_n for x in ["kill", "death", "attack"]): kill_src.append(os.path.join(source['path'], s))
                else: chase_src.append(os.path.join(source['path'], s))

            cfg_p = os.path.join(source['path'], "config.json")
            if os.path.exists(cfg_p):
                try:
                    with open(cfg_p, 'r') as f: config.update(json.load(f))
                except: print(f"  [!] Config error for {bot_name}")
        else:
            frames = [os.path.basename(source['path'])]
            # Match sounds in root by name
            all_root_s = [f for f in os.listdir(input_root) if os.path.isfile(os.path.join(input_root, f)) and f.lower().endswith(('.mp3', '.wav', '.ogg'))]
            for s in all_root_s:
                s_n = normalize(os.path.splitext(s.lower())[0])
                if bot_norm in s_n:
                    if any(x in s_n for x in ["kill", "death", "attack"]): kill_src.append(os.path.join(input_root, s))
                    else: chase_src.append(os.path.join(input_root, s))

        if not frames: continue

        # Copy Images
        mat_paths = []
        for i, f in enumerate(frames):
            ext = os.path.splitext(f)[1]
            d_n = f"frame{i+1}{ext}"
            src_p = source['path'] if source['type'] == 'file' else os.path.join(source['path'], f)
            shutil.copy(src_p, os.path.join(mat_dir, d_n))
            mat_paths.append(f"nextbot/{bot_name}/{d_n}")
            print(f"  -> Added image: {d_n}")

        # Copy Sounds
        c_p = []
        for i, s in enumerate(chase_src):
            ext = os.path.splitext(s)[1]
            d_n = f"chase{i+1}{ext}"
            shutil.copy(s, os.path.join(snd_dir, d_n))
            c_p.append(f"nextbot/{bot_name}/{d_n}")
            print(f"  -> Added chase sound: {d_n}")

        k_p = []
        for i, s in enumerate(kill_src):
            ext = os.path.splitext(s)[1]
            d_n = f"kill{i+1}{ext}"
            shutil.copy(s, os.path.join(snd_dir, d_n))
            k_p.append(f"nextbot/{bot_name}/{d_n}")
            print(f"  -> Added kill sound: {d_n}")

        # Write Lua
        with open(template_path, 'r') as f: lua = f.read()
        lua = lua.replace("{{PRINT_NAME}}", bot_disp)
        lua = lua.replace("{{CHASE_SOUNDS}}", "{" + ", ".join([f'"{p}"' for p in c_p]) + "}")
        lua = lua.replace("{{KILL_SOUNDS}}", "{" + ", ".join([f'"{p}"' for p in k_p]) + "}")
        lua = lua.replace("{{MATERIAL_PATHS}}", "{" + ", ".join([f'"{p}"' for p in mat_paths]) + "}")
        lua = lua.replace("{{MATERIAL_PATH}}", mat_paths[0] if mat_paths else "")
        lua = lua.replace("{{CLASS_NAME}}", f"npc_{bot_name}")
        for k, v in config.items(): lua = lua.replace("{{" + k.upper() + "}}", str(v))
        with open(lua_path, 'w') as f: f.write(lua)
        generated_count += 1
        print(f"  [OK] Done: {bot_name}")

    if generated_count > 0:
        with open(os.path.join(addon_path, "addon.json"), 'w') as f:
            json.dump({"title": addon_name, "type": "NPC", "tags": ["fun"]}, f, indent=4)
        print(f"\n[SUCCESS] Generated {generated_count} Nextbots in 'outputs/{addon_name}'")

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    generate_nextbots()
