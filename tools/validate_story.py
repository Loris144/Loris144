#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Validate game/data/story.json.

Checks:
  * the file is valid JSON with the expected top-level shape
  * every required scene id is present (and no unknown scene exists)
  * every scene has a matching `id` and a known `chapter`
  * every step has a valid `t` and the fields that step type requires
  * every `who` is a known cast key
  * every duel `opponent` matches the deck-id scheme
  * DP rules: watched duels give 0 DP, self-played wins give 700 DP
    (the prologue tutorial duel is the documented 0-DP exception)

Usage:  python3 tools/validate_story.py [path/to/story.json]
Exit code 0 = clean, 1 = problems found (all problems are listed).
"""
from __future__ import annotations

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_STORY = os.path.join(HERE, os.pardir, "game", "data", "story.json")

SCENE_IDS = [
    "prolog_intro", "prolog_home", "prolog_street", "prolog_shop",
    "prolog_tutorial", "prolog_kaiba",
    "dk_message", "dk_ship", "dk_arrive", "dk_weevil", "dk_rex", "dk_mai",
    "dk_keith", "dk_castle_gate", "dk_kaiba_cliff", "dk_pegasus",
    "bc_intro", "bc_rare_hunter", "bc_museum", "bc_strings", "bc_joey_harbor",
    "bc_qualify", "bc_finals_masked", "bc_finals_round1", "bc_kaiba_yugi",
    "bc_player_yugi", "bc_marik",
    "mem_travel", "mem_enter", "mem_court", "mem_thiefking", "mem_mahad",
    "mem_search", "mem_priest_seto", "mem_name", "mem_zorc", "mem_return",
    "fin_ceremonial", "fin_farewell", "fin_kog",
]

CHAPTERS = {"prolog", "dk", "bc", "memory", "finale"}

CAST = {
    "player", "yugi", "atem", "joey", "tea", "tristan", "grandpa", "kaiba",
    "mokuba", "pegasus", "weevil", "rex", "mai", "keith", "marik",
    "yami_marik", "ishizu", "odion", "bakura", "yami_bakura", "thiefking",
    "priest_seto", "mahad", "mana", "akhenaden", "strings", "rare_hunter",
    "zorc", "announcer", "narrator", "system",
}

# deck-id scheme
DECK_IDS = set()
for _base, _tiers in (
    ("yugi", (2, 3, 4, 5)), ("kaiba", (2, 3, 4, 5)), ("joey", (1, 2, 3, 4)),
    ("mai", (2, 3, 4)), ("weevil", (2,)), ("rex", (2,)), ("keith", (2,)),
    ("pegasus", (5,)), ("marik", (3,)), ("yami_marik", (4,)), ("ishizu", (3,)),
    ("odion", (3,)), ("bakura", (3,)), ("thiefking", (4,)),
    ("priest_seto", (4,)), ("rare_hunter", (2,)), ("strings", (3,)),
    ("random", (1, 2, 3, 4)),
):
    for _t in _tiers:
        DECK_IDS.add("%s_t%d" % (_base, _t))

DECK_RE = re.compile(r"^[a-z_]+_t[1-5]$")

MUSIC_TRACKS = {"town", "duel", "tense", "sad", "victory", "egypt"}

STEP_TYPES = {
    "say", "think", "stage", "choice", "duel", "choice_duel", "goto",
    "mission", "flag", "give", "free", "music",
}

TUTORIAL_SCENE = "prolog_tutorial"


class Report:
    def __init__(self):
        self.errors = []

    def err(self, where, msg):
        self.errors.append("%s: %s" % (where, msg))

    def ok(self):
        return not self.errors


def _need(rep, where, obj, key, types):
    if key not in obj:
        rep.err(where, "missing field %r" % key)
        return False
    if not isinstance(obj[key], types):
        rep.err(where, "field %r has wrong type %s" % (key, type(obj[key]).__name__))
        return False
    return True


def check_duel(rep, where, step, allow_dp=(0, 700)):
    ok = True
    if _need(rep, where, step, "opponent", str):
        opp = step["opponent"]
        if not DECK_RE.match(opp):
            rep.err(where, "opponent %r does not match the deck-id scheme" % opp)
            ok = False
        elif opp not in DECK_IDS:
            rep.err(where, "opponent %r is not a known deck id" % opp)
            ok = False
    if _need(rep, where, step, "mode", str):
        if step["mode"] not in ("play", "watch"):
            rep.err(where, "mode %r must be 'play' or 'watch'" % step["mode"])
    _need(rep, where, step, "must_win", bool)
    if _need(rep, where, step, "reward_dp", int):
        dp = step["reward_dp"]
        if dp not in allow_dp:
            rep.err(where, "reward_dp %r must be one of %s" % (dp, sorted(allow_dp)))
        if step.get("mode") == "watch" and dp != 0:
            rep.err(where, "watched duel must give 0 DP, has %r" % dp)
    if _need(rep, where, step, "reward_cards", list):
        for cid in step["reward_cards"]:
            if not isinstance(cid, int):
                rep.err(where, "reward_cards entry %r is not an int" % (cid,))
    return ok


def check_step(rep, where, step, scene_id, nested=False):
    if not isinstance(step, dict):
        rep.err(where, "step is not an object")
        return
    t = step.get("t")
    if t not in STEP_TYPES:
        rep.err(where, "unknown step type %r" % (t,))
        return

    if t in ("say", "think"):
        if _need(rep, where, step, "who", str):
            if step["who"] not in CAST:
                rep.err(where, "unknown speaker %r" % step["who"])
        if _need(rep, where, step, "text", str) and not step["text"].strip():
            rep.err(where, "empty text")

    elif t in ("stage", "mission"):
        if _need(rep, where, step, "text", str) and not step["text"].strip():
            rep.err(where, "empty text")

    elif t == "choice":
        if _need(rep, where, step, "options", list):
            if len(step["options"]) < 2:
                rep.err(where, "choice needs at least two options")
            for i, opt in enumerate(step["options"]):
                ow = "%s.option[%d]" % (where, i)
                if not isinstance(opt, dict):
                    rep.err(ow, "option is not an object")
                    continue
                _need(rep, ow, opt, "text", str)
                if _need(rep, ow, opt, "tag", str) and not opt["tag"].strip():
                    rep.err(ow, "empty tag")

    elif t == "duel":
        allow = (0,) if scene_id == TUTORIAL_SCENE else (0, 700)
        check_duel(rep, where, step, allow)

    elif t == "choice_duel":
        if nested:
            rep.err(where, "choice_duel may not be nested")
        if _need(rep, where, step, "self", dict):
            sw = where + ".self"
            if step["self"].get("t") != "duel":
                rep.err(sw, "self must be a duel step")
            else:
                if step["self"].get("mode") != "play":
                    rep.err(sw, "self duel must have mode 'play'")
                check_duel(rep, sw, step["self"])
        if _need(rep, where, step, "other", dict):
            other = step["other"]
            ow = where + ".other"
            if _need(rep, ow, other, "who", str):
                if other["who"] not in CAST:
                    rep.err(ow, "unknown duelist %r" % other["who"])
            if _need(rep, ow, other, "lines", list):
                if not other["lines"]:
                    rep.err(ow, "other branch has no lines")
                for i, sub in enumerate(other["lines"]):
                    check_step(rep, "%s.lines[%d]" % (ow, i), sub, scene_id, True)

    elif t == "goto":
        if _need(rep, where, step, "map", str) and not step["map"].strip():
            rep.err(where, "empty map id")
        _need(rep, where, step, "x", int)
        _need(rep, where, step, "y", int)

    elif t == "flag":
        if _need(rep, where, step, "set", str) and not step["set"].strip():
            rep.err(where, "empty flag name")
        if "value" not in step:
            rep.err(where, "missing field 'value'")

    elif t == "give":
        if _need(rep, where, step, "cards", list):
            for cid in step["cards"]:
                if not isinstance(cid, int):
                    rep.err(where, "cards entry %r is not an int" % (cid,))
        _need(rep, where, step, "dp", int)
        if not step.get("cards") and not step.get("dp"):
            rep.err(where, "give step rewards nothing")

    elif t == "music":
        if _need(rep, where, step, "track", str):
            if step["track"] not in MUSIC_TRACKS:
                rep.err(where, "unknown music track %r" % step["track"])

    # "free" carries no extra fields


def validate(path):
    rep = Report()
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        rep.err(path, "file not found")
        return rep, None
    except json.JSONDecodeError as exc:
        rep.err(path, "invalid JSON: %s" % exc)
        return rep, None

    if not isinstance(data, dict) or "scenes" not in data:
        rep.err(path, "top level must be an object with a 'scenes' key")
        return rep, None
    scenes = data["scenes"]
    if not isinstance(scenes, dict):
        rep.err(path, "'scenes' must be an object")
        return rep, None

    for sid in SCENE_IDS:
        if sid not in scenes:
            rep.err("scenes", "missing scene %r" % sid)
    for sid in scenes:
        if sid not in SCENE_IDS:
            rep.err("scenes", "unknown scene %r" % sid)

    for sid, scene in scenes.items():
        where = "scene %s" % sid
        if not isinstance(scene, dict):
            rep.err(where, "scene is not an object")
            continue
        if scene.get("id") != sid:
            rep.err(where, "scene 'id' is %r, expected %r" % (scene.get("id"), sid))
        if scene.get("chapter") not in CHAPTERS:
            rep.err(where, "unknown chapter %r" % scene.get("chapter"))
        if not _need(rep, where, scene, "steps", list):
            continue
        if not scene["steps"]:
            rep.err(where, "scene has no steps")
        for i, step in enumerate(scene["steps"]):
            check_step(rep, "%s.steps[%d]" % (where, i), step, sid)

    return rep, scenes


def stats(scenes):
    counts = {}
    lines = 0
    for scene in scenes.values():
        stack = list(scene["steps"])
        while stack:
            step = stack.pop()
            t = step.get("t")
            counts[t] = counts.get(t, 0) + 1
            if t in ("say", "think"):
                lines += 1
            if t == "choice_duel":
                stack.extend(step.get("other", {}).get("lines", []))
    total = sum(counts.values())
    return total, lines, counts


def main(argv):
    path = argv[1] if len(argv) > 1 else DEFAULT_STORY
    path = os.path.abspath(path)
    rep, scenes = validate(path)
    if not rep.ok():
        print("FAIL %s" % path)
        for e in rep.errors:
            print("  - %s" % e)
        print("%d problem(s)" % len(rep.errors))
        return 1
    total, lines, counts = stats(scenes)
    print("OK %s" % path)
    print("  scenes:          %d" % len(scenes))
    print("  steps (total):   %d" % total)
    print("  dialogue lines:  %d (say + think)" % lines)
    print("  step types:      %s"
          % ", ".join("%s=%d" % kv for kv in sorted(counts.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
