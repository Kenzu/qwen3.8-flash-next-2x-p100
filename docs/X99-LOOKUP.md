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

### Optional continuation length experiment

With four sources enabled, set `FNX_LOOKUP_EXTEND_MIN` to `"8"` to propose the full lookup window when the matching history covers at least eight tokens. Smaller matches keep the upstream length rule. The existing lookup limit, image boundary and end of available history still cap each proposal. The default of zero disables extension. This tests the continuation-length choice separately from multi-source search.

On the two P100s, the isolated four-source run generated at 85.00 tok/s on Python and 87.40 tok/s on Markdown. Enabling the eight-token extension threshold gave 83.45 and 86.70 tok/s. Both saved edit responses matched the corresponding control text. Keep extension disabled for this profile.

### Optional eight-token index

With a single request in flight (`--batch 1`), `FNX_LOOKUP_INDEX8=1` also considers the four most recent earlier occurrences of the last eight tokens. The CPU index is private to each generation and includes only the prompt and accepted output. The longest eligible history wins, with the most recent occurrence breaking ties. The default is zero. [Basalt suffix lookup](https://github.com/jesdga95/basalt/blob/899e820af777705cd29b35b1deb8612f24c42c5e/include/basalt/spec/suffix_drafter.hpp)

For this A/B, use the same executable and two-card IQ3_S profile for both runs. Set `FNX_PREFETCH_WANT=2`, `FNX_PF_PASS=6`, `FNX_PF_TAIL_MIB=3750`, `FNX_CKPT_EVERY=24576`, `FNX_LOOKUP_SOURCES=4` and `FNX_LOOKUP_EXTEND_MIN=0`. Change only `FNX_LOOKUP_INDEX8` between zero and one. Run the benchmark above with `--tests fresh,edit,long` after each fresh load.
