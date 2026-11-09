"""Enlarge actual HUD regions beside the synchronized full capture, entirely offline."""
import argparse
import os
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("source", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--ffmpeg", default=os.environ.get("FFMPEG", "ffmpeg"))
parser.add_argument("--font", type=Path, default=Path("C:/Windows/Fonts/segoeui.ttf"))
args = parser.parse_args()
font = str(args.font.resolve()).replace("\\", "/").replace(":", r"\:")
filters = [
    "[0:v]split=5[full][map][units][orders][support]",
    "color=c=0x0b1113:s=1280x720:r=24:d=15[bg]",
    "[full]scale=640:360[fullsmall]",
    "[map]crop=270:290:0:610,scale=550:590[maplarge]",
    "[units]crop=300:330:1300:50,scale=550:605[unitslarge]",
    "[orders]crop=280:185:1320:715,scale=560:370[orderslarge]",
    "[support]crop=300:330:1300:50,scale=550:605[supportlarge]",
    "[bg][fullsmall]overlay=x=24:y=96[a]",
    "[a][maplarge]overlay=x=704:y=96:enable='lt(t,1)+between(t,9,10.999)'[b]",
    "[b][unitslarge]overlay=x=704:y=96:enable='between(t,1,4.999)'[c]",
    "[c][orderslarge]overlay=x=704:y=190:enable='between(t,5,8.999)+gte(t,13.5)'[d]",
    "[d][supportlarge]overlay=x=704:y=96:enable='between(t,11,13.499)'[e]",
]
texts = [
    ("FULL FRAME", 24, 26, 20, None),
    ("ENLARGED DETAIL (SAME FRAME)", 704, 26, 20, None),
    ("Fixed map. Focused command tools.", 24, 58, 27, None),
    ("Real engine frames / normal speed / 24 fps", 24, 672, 18, None),
]
phases = [
    (0, 1, "Fixed navigation", "The map stays in the same place."),
    (1, 2.5, "Units", "Open the roster beside the battle."),
    (2.5, 5, "Search", "Type a callsign to narrow the list."),
    (5, 7, "Focus", "Return to the squad with orders ready."),
    (7, 9, "Base", "Construction costs and bound-key hints."),
    (9, 11, "Layers", "Map controls stay beside navigation."),
    (11, 13.5, "Support", "Availability and cooldowns together."),
    (13.5, 15, "Back to battle", "Close the workspace and keep command."),
]
for start, end, title, detail in phases:
    condition = f"gte(t,{start})*lt(t,{end})"
    texts.extend([(title, 24, 510, 30, condition), (detail, 24, 555, 22, condition)])
last = "e"
for i, (text, x, y, size, condition) in enumerate(texts):
    name = f"text{i}"
    draw = f"drawtext=fontfile='{font}':text='{text}':x={x}:y={y}:fontsize={size}:fontcolor=0xe9e9df"
    if condition:
        draw += f":enable='{condition}'"
    filters.append(f"[{last}]{draw}[{name}]")
    last = name
command = [args.ffmpeg, "-y", "-loglevel", "error", "-i", str(args.source),
           "-filter_complex", ";".join(filters), "-map", f"[{last}]", "-t", "15",
           "-c:v", "libvpx-vp9", "-crf", "26", "-b:v", "0", "-cpu-used", "4",
           "-threads", "4", "-pix_fmt", "yuv420p", "-an", str(args.output)]
subprocess.run(command, check=True)
