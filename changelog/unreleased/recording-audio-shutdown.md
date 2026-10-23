+++
title = "Finish recorded battles with clean audio shutdown"
summary = "Timed battle recordings stop their audio before the final recording frames."
kind = "fixed"
+++

When a battle recording reaches its requested end time, playback stops and two final frames allow the audio mixer to release its active streams before shutdown. This addresses audio-stream leak warnings in recorded demos. Ordinary timed runs keep their existing exit behavior.
