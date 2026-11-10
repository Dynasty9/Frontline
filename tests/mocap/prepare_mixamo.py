"""Install the user's Mixamo downloads locally; preserve pack provenance."""
from pathlib import Path
import shutil
import zipfile
import hashlib
import json

root = Path(__file__).resolve().parents[2] / 'assets/local_mocap/mixamo'
downloads = Path.home() / 'Downloads'
root.mkdir(parents=True, exist_ok=True)
for filename, folder in [('Shooter Pack.zip', 'shooter'), ('Basic Shooter Pack.zip', 'basic_shooter'), ('Rifle 8-Way Locomotion Pack.zip', 'rifle_locomotion'), ('Pro Rifle Pack.zip', 'pro_rifle'), ('Male Injured Pack.zip', 'injured'), ('Gestures Pack Basic.zip', 'gestures')]:
    if not (downloads / filename).exists():
        continue
    with zipfile.ZipFile(downloads / filename) as archive:
        for item in archive.infolist():
            if item.is_dir() or not item.filename.lower().endswith('.fbx'):
                continue
            name = Path(item.filename).name
            if name == 'Ch15_nonPBR.fbx':
                continue
            target = root / folder / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(item) as source, target.open('wb') as output:
                shutil.copyfileobj(source, output)
shutil.copy2(downloads / 'Ch15_nonPBR.fbx', root / 'Swat.fbx')
shutil.copy2(downloads / 'Rifle Kneel To Prone.fbx', root / 'Rifle Kneel To Prone.fbx')
for filename in ['Rifle Crouch Walk.fbx', 'Rifle Prone To Kneel.fbx', 'Rifle Put Away.fbx', 'Grab Rifle From Back.fbx', 'Put Back Rifle.fbx']:
    if (downloads / filename).exists():
        shutil.copy2(downloads / filename, root / filename)
for filename in ['Rifle Jump In Place.fbx', 'Talking.fbx', 'Laughing.fbx', 'Arm Stretching.fbx', 'Rifle Idle.fbx', 'Picking Up Object.fbx']:
    if (downloads / filename).exists():
        (root / 'activities').mkdir(parents=True, exist_ok=True)
        shutil.copy2(downloads / filename, root / 'activities' / filename)
manifest = Path(__file__).resolve().parents[2] / 'assets/infantry/additional-clips.json'
for clip in json.loads(manifest.read_text())['clips']:
    source = downloads / clip['download']
    if not source.exists():
        continue
    # Generic Mixamo names such as Walking can refer to unrelated downloads.
    if hashlib.sha256(source.read_bytes()).hexdigest() != clip['sha256']:
        raise ValueError(f"Different download at {source}; preserve the installed clip")
    shutil.copy2(source, root / 'activities' / clip['installed'])
print('Installed Mixamo files under', root)
