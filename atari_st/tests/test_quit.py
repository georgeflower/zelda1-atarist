"""The Esc question (src/quit.s) and its wiring: the pieces that must agree with each other."""
from __future__ import annotations

import re
import unittest
from pathlib import Path

SRC = Path(__file__).resolve().parents[1] / "src"


def source(name: str) -> str:
    return (SRC / name).read_text(encoding="utf-8")


def equ(text: str, name: str) -> int:
    match = re.search(rf"^\s*\.equ {name},\s*(\w+)", text, re.M)
    assert match, name
    return int(match.group(1), 0)


class QuitWiringTests(unittest.TestCase):
    def test_the_mode_is_new_and_dispatched(self) -> None:
        main = source("main.s")
        modes = {name: equ(main, name) for name in re.findall(r"^\s*\.equ (MODE_\w+),", main, re.M)}
        self.assertEqual(len(set(modes.values())), len(modes), modes)
        self.assertIn("cmp.b #MODE_QUIT, %d0", main)
        self.assertIn("farstub update_quit_far, update_quit", main)
        self.assertIn('.include "quit.s"', main)

    def test_the_title_and_the_death_still_end_the_game_at_once(self) -> None:
        # main_loop tests the two modes with one compare, which needs them to follow each other
        main = source("main.s")
        self.assertEqual(equ(main, "MODE_DEATH"), equ(main, "MODE_INTRO") + 1)
        self.assertIn("subq.b #MODE_INTRO, %d0", main)

    def test_the_menu_turns_the_request_into_the_question(self) -> None:
        menu = source("menu.s")
        self.assertIn("bsr quit_open", menu)
        self.assertRegex(menu, r"update_menu:[\s\S]*?OFF_EXIT_REQUESTED[\s\S]*?bsr menu_close")

    def test_the_three_choices(self) -> None:
        quit_source = source("quit.s")
        lines = re.findall(r'\.asciz "([^"]+)"', quit_source)
        self.assertEqual(lines[:3], ["QUIT WITHOUT SAVING", "SAVE AND QUIT", "BACK TO GAME"])
        self.assertEqual(equ(quit_source, "QUIT_LINES"), 3)
        for text in lines[:3]:
            self.assertTrue(re.fullmatch(r"[A-Z0-9 ]+", text))     # text_draw knows capitals, digits and the space
        # SAVE AND QUIT is the middle line and saves the profile's slot
        self.assertRegex(quit_source, r"cmp\.b #1, %d2\s+bne 5f\s+moveq #0, %d0\s+\| SAVE AND QUIT\s+move\.b OFF_PROFILE\(%a5\), %d0\s+bsr save_store_game")

    def test_the_variables_are_declared(self) -> None:
        globals_source = source("globals.s")
        for name in ("QUIT_SEL", "QUIT_KEYS"):
            self.assertRegex(globals_source, rf"gvar {name},")


class LoadingTests(unittest.TestCase):
    def test_every_read_shows_the_word(self) -> None:
        loader = source("loader.s")
        self.assertRegex(loader, r"level_load:\n\s*movem\.l [^\n]+\n\s*bsr loading_show")
        self.assertIn('" LOADING "', loader)
        # the box is as wide as the word with a blank cell either side
        text = re.search(r'loading_text:\s*\.asciz "([^"]*)"', loader).group(1)
        blank = re.search(r'loading_blank:\s*\.asciz "([^"]*)"', loader).group(1)
        self.assertEqual(len(text), len(blank))


if __name__ == "__main__":
    unittest.main()
