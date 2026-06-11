# HumanSL model placement

Place the KataGo HumanSL model file here:

```text
GoTutor/Resources/Models/HumanSL/b18c384nbt-humanv0.bin.gz
```

You may also use another KataGo-compatible human SL model, but the app first looks for `b18c384nbt-humanv0.bin.gz`.

The model file does not need to be cross-compiled. It is a runtime neural-network weight file loaded by KataGo.

Large `*.bin.gz` model files are intentionally ignored by git and should not be committed.

If the embedded iOS KataGo core does not support the `-human-model` analysis argument, rebuild the KataGo iOS/Metal library from a KataGo version that includes HumanSL support, then replace the local KataGo static library artifacts in `GoTutor/KataGoCore/`.
