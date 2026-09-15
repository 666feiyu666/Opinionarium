# Playback and data

## Development recording

The local recording is an integrated baseline with 500 agents, 50 rounds,
seed 20260910, and positive opinion leaders. It uses the model's existing
baseline configuration without visualization-specific mechanism changes.

The original results are retained under the model project's ignored
`outputs/opinionarium/20260915T105128Z/baseline_positive_20260910_50/`.
A byte-identical copy is in Opinionarium's ignored
`data/baseline_positive_20260910_50/`.

This contains 25,500 state rows, 1,700 messages and 40,570 exposures.
The recording's manifest contains the actual model revision, resolved
configuration, leader IDs, generation timestamps and CSV SHA-256 hashes.
The model was invoked once through its existing Python interfaces; no
permanent exporter or Python bridge was added to either project.

## Result folder

Processing directly reads the six tables produced by the model's
`simulation_frames()` function:

| File | Required fields |
| --- | --- |
| states.csv | round, agent_id, a, b, signed_mean |
| origination.csv | round, agent_id, did_originate, origination_probability, message_id |
| messages.csv | round, message_id, producer_id, stance |
| exposures.csv | round, consumer_id, message_id, producer_id, stance |
| aggregates.csv | round, consumer_id, n_support, n_oppose, weighted_support, weighted_oppose, a_before, b_before, a_after, b_after |
| network.csv | round, consumer_id, producer_id |

Extra columns are allowed. Node IDs need not be contiguous. State snapshots
include round 0; origins and aggregates have one row per agent per subsequent
round, including silent agents. Empty message and exposure tables retain
their headers. The network table stores complete snapshots, not edge deltas.

Alongside these tables, `manifest.json` provides `scenario`, `orientation`,
`seed`, `rounds`, `agent_count`, `model_revision` and `leader_ids`.
The development manifest also retains the complete config, leader direction
groups, model dirty status and optional `files` mapping from CSV filename to
SHA-256. When that mapping exists, hashes are verified before parsing.

This loader targets the agreed baseline recording metadata. Earlier
scenario diagnostic folders may have different manifest structures;
they are not automatically treated as compatible just because they contain CSVs.

Loading is atomic: a bad recording shows an error without replacing the
previous valid recording. Press Escape to dismiss the error, then Space
to resume the previous recording. File selection is paused. Large files
are loaded synchronously before playback begins.

## Visual meaning

- Node fill: private signed belief, from negative pink through neutral to positive teal.
- Message fill: binary message stance (-1 or +1), independent of the author's mean.
- Node area: a fixed increasing function of follower count throughout the recording.
- Double ring: recorded opinion-leader identity.
- Expanding/contracting pale ring: gain/loss of followers at the round boundary.
- Arrival ripple: actual message exposure.
- Network arrow: follower to followed; message motion: author to consumer.
- Node positions, breathing, curve bends and travel times are presentation only.

Positions are deterministic and fixed for the whole recording. Layout uses
maximum recorded node sizes to reduce later overlap. It does not encode a
social or opinion distance, and uses its own random seed.

Each round displays origination, delivery, then a synchronous state commit.
At most 64 message particles are in flight. Exposures are shown in batches
without sampling or dropping any; animation order has no model-causal meaning.
All recorded opinions and edges are applied together after delivery.
Colors and sizes then ease toward the recorded values. The inspector labels
the committed state separately from the active round's recorded events.

At 1x, a dense round takes longer than a sparse round. Speed is a playback
multiplier, not simulation time. The final state stays on screen after round 50.

## Controls

| Control | Action |
| --- | --- |
| Space | Play/pause, including decorative animation |
| Right arrow | Finish the active round and pause, or play one round from a boundary |
| R | Return to the same recording's initial state, paused |
| + / - | Playback speed from 0.25x to 8x |
| E | Toggle the whole network; selected-node relationships remain visible |
| L | Choose a compatible recording folder |
| Click | Inspect a node and its local relationships |
| Drag | Pan the canvas |
| Mouse wheel | Zoom around the cursor |
| V | Reset the view |
| S | Save a PNG under ignored out/ |

## Verification

With Processing 4 on PATH:

```powershell
./scripts/Run.ps1 -Verify
./scripts/Run.ps1 -VisualCheck
```

If needed, supply `-ProcessingHome 'D:/ProgramData/Processing/current'`.
The script uses Processing's bundled JDK and libraries. Every invocation
builds into a new ignored directory; it does not replace or delete earlier builds.

The replay checks exercise the actual Processing-preprocessed classes:
complete 50-round playback at 1x and 8x, every committed state and network,
exposure totals, particle cap, pause at every phase, single-step, reset,
view independence, empty rounds, non-contiguous IDs and malformed input.

The optional visual check opens the real P2D renderer briefly, saves
initial/propagation/inspector screenshots under out/, reports frame-rate
and heap samples, then exits. It is a rendering smoke test, not a claim
about sustained performance on other machines. The regular run opens
paused so the viewer controls the presentation.

## Local verification result (2026-09-15)

Processing 4.5.6 / P2D, 1440 x 900 at pixel density 1 on the development machine:

- CSV loading: approximately 0.79 seconds in the final visual check.
- Typical playback: 58.8 FPS average during the measured window.
- Densest exposure round (round 2, 1,360 exposures), whole network visible:
  59.1 FPS average, 43.1 FPS minimum sampled smoothed frame rate.
- Sampled Java heap: approximately 303 MB during the dense check (not total process RAM).
- Complete round 50 rendered successfully with 1,742 relationships.
- Full controller checks passed at 1x and 8x, delivering all 40,570 exposures.

These are short local smoke-test measurements. Screenshots are saved under out/;
final-state rendering in the test follows accelerated controller execution.
