"""Encode reviewed environment motion frames without altering the native scene."""
import argparse, hashlib, json, os, shutil, subprocess
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--entry',required=True)
parser.add_argument('--source-ref',required=True)
args=parser.parse_args()
root=Path.cwd(); capture=root/'build/media-review'; out=root/'changelog/unreleased'/args.entry
ff=os.environ.get('FFMPEG') or shutil.which('ffmpeg')
if not ff:
    parser.error('Set FFMPEG or put ffmpeg on PATH.')
fonts=[os.environ.get('SHOWCASE_FONT', ''), 'C:/Windows/Fonts/arial.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', '/System/Library/Fonts/Supplemental/Arial.ttf']
font=next((Path(f).as_posix().replace(':', r'\:') for f in fonts if f and Path(f).is_file()), None)
if not font:
    parser.error('Set SHOWCASE_FONT to a readable TrueType font.')
meta=json.loads((capture/'capture.json').read_text(encoding='utf-8-sig'))
parts=[]
for i,view in enumerate(meta['views']):
    frames = sorted((capture/f'view-{i}').glob('*.png'))
    if len(frames) != view['frames']:
        raise SystemExit(f'Incomplete view {i}: {len(frames)} frames')
    label=capture/f'label-{i}.txt'
    label.write_text(view['label']+'   |   Current PR - native camera capture',encoding='utf-8')
    part=capture/f'part-{i}.webm'
    filters=f"pad=1280:768:0:48:color=0x101518,drawtext=fontfile='{font}':textfile='build/media-review/label-{i}.txt':fontcolor=white:fontsize=21:x=22:y=13"
    subprocess.run([ff,'-y','-v','error','-framerate','30','-i',str(capture/f'view-{i}/%04d.png'),'-vf',filters,'-c:v','libvpx-vp9','-crf','29','-b:v','0','-deadline','good','-cpu-used','4','-pix_fmt','yuv420p','-an',str(part)],check=True)
    parts.append(part)
concat=capture/'concat.txt'; concat.write_text(''.join("file '"+p.as_posix()+"'\n" for p in parts))
clip=out/'native-tour.webm'
subprocess.run([ff,'-y','-v','error','-f','concat','-safe','0','-i',str(concat),'-c','copy',str(clip)],check=True)
subprocess.run([ff,'-y','-v','error','-ss','2','-i',str(clip),'-frames:v','1','-q:v','3',str(out/'native-tour.jpg')],check=True)
subprocess.run([ff,'-v','error','-i',str(clip),'-f','null','-'],check=True)
for time in [0,2,3.9,4.1,len(parts)*4-0.1]:
    subprocess.run([ff,'-y','-v','error','-ss',str(time),'-i',str(clip),'-frames:v','1',str(capture/f'check-{time}.jpg')],check=True)
meta = json.loads(json.dumps(meta).replace(root.as_posix(), '.').replace(str(root).replace('\\', '\\\\'), '.'))
meta.update(source_ref=args.source_ref,clip='native-tour.webm',poster='native-tour.jpg',clip_sha256=hashlib.sha256(clip.read_bytes()).hexdigest(),seconds=len(parts)*4,audio=False,codec='VP9',resolution='1280x768 (48-pixel label above uncropped 1280x720 source)',command='godot --path . --fixed-fps 30 --resolution 1280x720 --script tools/showcase/environment-motion.gd -- --aivai --seed=3 --offscreen --nohud --set=perf:0 --preset=high --mood=day --motion-stage='+meta['stage']+' --motion-output=build/media-review')
(out/'native-tour.json').write_bytes((json.dumps(meta,indent=2)+'\n').encode('utf-8'))
print(json.dumps({'clip':str(clip),'bytes':clip.stat().st_size,'seconds':meta['seconds'],'sha256':meta['clip_sha256']}))
