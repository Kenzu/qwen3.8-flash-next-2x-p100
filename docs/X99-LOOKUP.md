# Two-card X99 lookup test

This branch adds one engine change to Megla's `404de0a` two-card port. At `FNX_LOOKUP_SOURCES=4`, each lookup considers up to four recent occurrences of the current trigram and picks the longest matching history with an eligible continuation. The newest occurrence wins ties. The default is one, as in the upstream engine. The selection rule comes from [Basalt's suffix drafter](https://github.com/jesdga95/basalt/blob/899e820af777705cd29b35b1deb8612f24c42c5e/src/spec/suffix_drafter.cpp).

Use the upstream build procedure for two P100s and select the existing IQ3_S files on NVMe. To repeat the isolated comparison, start both profiles from the same prepared exact-routing profile and the same executable. Python and Markdown edits use the developer's original benchmark inputs.

```bash
python3 - "$DATA/profile.json" "$DATA/profile-lookup-control.json" "$DATA/profile-lookup-four.json" <<'PY'
import json
import sys
from pathlib import Path

base, control, experiment = map(Path, sys.argv[1:])
profile = json.loads(base.read_text())
for destination, sources in [(control, "1"), (experiment, "4")]:
    profile["env"].update(FNX_ROUTE_PRIOR="0", FNX_PREFETCH_WANT="2", FNX_LOOKUP_SOURCES=sources)
    destination.write_text(json.dumps(profile, indent=2) + "\n")
PY
```

Point `exe` in both output profiles at the newly built two-card binary. Run `bash run.sh "$DATA" --config "$DATA/profile-lookup-control.json" --port 18080`. Once the engine is loaded, run the command below in a second terminal. Stop this server, then repeat with `profile-lookup-four.json` and a new output filename.

```bash
python3 bench/bench.py --strata-dir "$DATA/strata-v0.2.9" \
    --url http://127.0.0.1:18080 --wait 6 --ours iq3_s \
    --tests fresh,edit,long,medium,image --out "$DATA/lookup-control-results.json"
```
