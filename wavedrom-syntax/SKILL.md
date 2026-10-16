---
name: wavedrom-syntax
description: Self-contained WaveDrom/WaveJSON syntax handbook for creating, editing, and checking digital timing diagrams, including wave symbols, data labels, clocks, grouping, timing alignment, annotations, and arrows.
disable-model-invocation: true
---

# WaveDrom Syntax Handbook

Use the rules and examples in this file to write accurate, readable WaveDrom timing diagrams. Prefer strict JSON for saved `.json` files.

## Basic structure

A WaveJSON diagram is an object whose `signal` array contains lanes, groups, and separators.

```json
{
  "signal": [
    { "name": "clk", "wave": "p......" },
    { "name": "valid", "wave": "01...0." },
    { "name": "data", "wave": "x.=..x.", "data": ["A"] }
  ],
  "config": { "hscale": 2 }
}
```

- A normal lane uses `name` (label) and `wave` (waveform).
- `{}` inserts a vertical blank spacer.
- `["Group name", lane1, lane2, ...]` groups lanes; groups may nest.
- Root-level `edge` holds connections; `head`, `foot`, and `config` control presentation.
- WaveDrom tutorial snippets commonly use JavaScript object literals (unquoted keys and single quotes). Strict JSON requires double-quoted property names and strings, and excludes comments and trailing commas.

## Wave symbols

Each character in `wave` normally represents one time slot; `period` and `phase` modify horizontal placement.

| Symbol | Meaning |
|---|---|
| `0`, `1` | Logic low, logic high |
| `x` | Undefined/unknown |
| `z` | High impedance |
| `u`, `d` | Weak pull-up, weak pull-down |
| `.` | Extend the previous state or data segment by one slot |
| `=` | New data-value segment using default data style |
| `2`–`9` | New data-value segments with alternative visual styles |
| `p`, `n` | Positive-edge / negative-edge clock patterns |
| `P`, `N` | Clock patterns with edge arrows |
| `h`, `l` | High/low clock-level symbols used for clock composition |
| `H`, `L` | High/low clock-level variants with emphasized edge markers |
| `|` | Extend the preceding state and draw a visual gap |

Important: `.` holds the previous segment. Consecutive `=` characters start *different* data segments.

```json
{
  "signal": [
    { "name": "enable", "wave": "0.1..0." },
    { "name": "bus", "wave": "x.=..3.x", "data": ["ADDR", "DATA"] },
    { "name": "clk", "wave": "P......." }
  ]
}
```

## Data buses and labels

Give a label for each new labeled data segment (`=`, `2`–`9`) in left-to-right order.

```json
{
  "signal": [
    { "name": "addr", "wave": "x.==.x", "data": ["A0", "A1"] },
    { "name": "data", "wave": "x.2.3x", "data": ["0x12", "0x34"] }
  ]
}
```

- `x.==.x` has **two** new data segments; `x.=..x` has **one**.
- `data` may be an array, or a whitespace-separated string for simple labels. Use an array when labels contain spaces.
- The digits select visual styles; do not assume a particular rendered color.
- A lane can depict a multi-bit bus without implying numeric values unless they are provided as labels.

## Clock, period, and phase

```json
{
  "signal": [
    { "name": "clk", "wave": "p......." },
    { "name": "marked_clk", "wave": "P......." },
    { "name": "slow_clk", "wave": "p...", "period": 2 },
    { "name": "cmd", "wave": "x.=..x..", "data": ["READ"], "phase": 0.5 }
  ]
}
```

- `p` and `n` create continuous positive-/negative-polarity clock patterns; `P` and `N` show working-edge markers.
- `h`, `l`, `H`, and `L` can compose gated/irregular clock representations; use deliberate transitions rather than treating them as ordinary constant-value annotations.
- `period` multiplies horizontal duration per character for that lane (normally a positive integer).
- `phase` offsets a lane relative to the common grid; fractional values such as `0.5` are useful for half-slot alignment.
- When applying `phase` or unequal `period` values, compare the *rendered positions*, not just character indices.

## Groups, spacers, and time gaps

```json
{
  "signal": [
    ["Master",
      { "name": "req", "wave": "01..0." },
      ["Payload",
        { "name": "addr", "wave": "x.=..x", "data": ["A0"] }
      ]
    ],
    {},
    ["Slave", { "name": "ack", "wave": "0..10." }]
  ]
}
```

A group is an array whose first element is the displayed group label. `{}` creates **vertical** separation between rows. `|` inside a `wave` adds a **horizontal** time gap:

```json
{ "signal": [{ "name": "clk", "wave": "p...|..." },
             { "name": "req", "wave": "01..|0.." }] }
```

Align gap locations across lanes when they represent the same omitted time interval.

## Nodes and annotation edges

A `node` string places named markers on the lane's time grid. Use `.` for positions without a node. Lowercase nodes are normally visible; uppercase node IDs can be used for invisible anchor points.

```json
{
  "signal": [
    { "name": "req", "wave": "01....", "node": ".a...." },
    { "name": "ack", "wave": "0..10.", "node": "...b.." }
  ],
  "edge": ["a~>b response"]
}
```

Common edge forms (the first and last characters identify existing nodes):

| Form | Meaning |
|---|---|
| `a-b` | Straight line |
| `a->b` | Straight arrow |
| `a<->b` | Double-ended arrow |
| `a~b` | Curved line |
| `a~>b` | Curved arrow |
| `a-~>b` | Smooth/curved arrow variant |
| `a-|b` | Right-angle connection |
| `a-|>b` | Right-angle arrow |
| `a-|-b` | Orthogonal connection with additional bend |
| `a-|->b` | Orthogonal arrow with additional bend |
| `a+b` | Marker/cross-style connection |

Edge strings may add text after the connector token: `"a->b latency"`. Shape operators include `-` (horizontal), `|` (vertical), `~` (curving), `/` (diagonal), and `#` (label placement). Use one of the documented forms above before composing more complex connections.

Nodes must be unique within the drawing when used as edge endpoints. Make `node` positions consistent with the lane's `wave` slots and any `period`/`phase` adjustments. Dedicated annotation lanes may contain `node` without a visible `wave` when useful.

## Titles, axes, and scaling

```json
{
  "signal": [
    { "name": "clk", "wave": "p....." },
    { "name": "data", "wave": "x.==.x", "data": ["A", "B"] }
  ],
  "head": { "text": "Bus transaction", "tick": 0, "every": 2 },
  "foot": { "text": "Illustrative waveform", "tock": 0 },
  "config": { "hscale": 2 }
}
```

- `head.text` and `foot.text` set captions; `tick` numbers grid lines, while `tock` numbers intervals.
- `every` shows a tick/tock label at every Nth position.
- `config.hscale` is an integer >= 1; it controls horizontal scaling.
- `config.skin` selects a supported rendering skin such as `"default"` or `"narrow"` when available.
- For advanced title formatting, `head.text` / `foot.text` can be JsonML arrays. Example:

```json
{
  "signal": [{ "name": "clk", "wave": "p..." }],
  "head": {
    "text": ["tspan", ["tspan", {"class": "h2"}, "Timing"], " diagram"]
  }
}
```

## Common patterns

**Handshake / control and bus value**

```json
{
  "signal": [
    { "name": "clk", "wave": "p......" },
    { "name": "valid", "wave": "01...0." },
    { "name": "ready", "wave": "0..1.0." },
    { "name": "payload", "wave": "x.=..x.", "data": ["D0"] }
  ]
}
```

**Multiple labeled bus segments**

```json
{
  "signal": [
    { "name": "clk", "wave": "P......." },
    { "name": "bus", "wave": "x.2.3.4x", "data": ["IDLE", "CMD", "RESP"] }
  ]
}
```

## Before returning the diagram

1. Check that the output is valid **strict JSON** when writing a `.json` file.
2. Check `signal` nesting, group labels, and comma placement.
3. Count new bus-data segments (`=`, `2`–`9`); match the number and order of labels in `data`.
4. Confirm `.` repeats the intended preceding segment, while `|` denotes a visual gap.
5. Confirm `node` markers exist, are unique for endpoint use, and every `edge` references valid markers.
6. Confirm the intended row alignments after `period`, `phase`, or time gaps.
7. When a local WaveDrom renderer is available, render and inspect the drawing; describe verification as performed only when actually performed.
8. Deliver the WaveJSON in a code block or file, with an SVG if rendering was requested and is available.
