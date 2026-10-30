"""Install the user's Mixamo downloads locally; preserve pack provenance."""
from pathlib import Path
import shutil
import zipfile

root = Path(__file__).resolve().parents[2] / 'assets/local_mocap/mixamo'
downloads = Path.home() / 'Downloads'
root.mkdir(parents=True, exist_ok=True)
for filename, folder in [('Shooter Pack.zip', 'shooter'), ('Basic Shooter Pack.zip', 'basic_shooter'), ('Rifle 8-Way Locomotion Pack.zip', 'rifle_locomotion'), ('Pro Rifle Pack.zip', 'pro_rifle')]:
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
print('Installed Mixamo files under', root)
