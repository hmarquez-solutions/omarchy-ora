import datetime as dt
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("ora", str(ROOT / "ora"))
spec = importlib.util.spec_from_loader(loader.name, loader)
ora = importlib.util.module_from_spec(spec)
loader.exec_module(ora)


def litcal_event(date, name, grade, color="green", **extra):
    event = {"date": f"{date}T00:00:00+00:00", "name": name, "grade": grade, "color": [color], "is_vigil_mass": None,
             "liturgical_season_lcl": "Ordinary Time", "liturgical_year": "YEAR II", "psalter_week": 2, "readings": {}}
    event.update(extra)
    return event


class CalendarTests(unittest.TestCase):
    def test_easter(self):
        self.assertEqual(ora.easter(2026), dt.date(2026, 4, 5))
        self.assertEqual(ora.easter(2027), dt.date(2027, 3, 28))

    def test_major_days(self):
        self.assertEqual(ora.liturgical_day(dt.date(2026, 4, 5)), ("Easter Sunday", "white"))
        self.assertEqual(ora.liturgical_day(dt.date(2026, 5, 24)), ("Pentecost Sunday", "red"))
        self.assertEqual(ora.liturgical_day(dt.date(2026, 12, 8)), ("Immaculate Conception", "white"))

    def test_seasons(self):
        self.assertEqual(ora.liturgical_day(dt.date(2026, 3, 1))[0], "Lent")
        self.assertEqual(ora.liturgical_day(dt.date(2026, 12, 1))[0], "Advent")
        self.assertEqual(ora.liturgical_day(dt.date(2026, 8, 30))[0], "Ordinary Time")
        self.assertEqual(ora.season_of(dt.date(2026, 4, 20)), "Easter")

    def test_rosary_cycle(self):
        self.assertEqual(ora.mysteries(dt.date(2026, 8, 31))[0], "Joyful Mysteries")
        self.assertEqual(ora.mysteries(dt.date(2026, 9, 3))[0], "Luminous Mysteries")
        self.assertEqual(len(ora.mysteries(dt.date(2026, 9, 4))[1]), 5)


class LitCalTests(unittest.TestCase):
    def test_optional_memorial_headlines_over_weekday(self):
        events = [
            litcal_event("2026-09-05", "Saturday of the 22nd Week of Ordinary Time", 0),
            litcal_event("2026-09-05", "Saint Teresa of Calcutta, Virgin", 2, "white", liturgical_year=None),
            litcal_event("2026-09-05", "Saturday Memorial of the Blessed Virgin Mary", 2, "white", liturgical_year=None),
            litcal_event("2026-09-05", "23rd Sunday of Ordinary Time Vigil Mass", 5, is_vigil_mass=True),
        ]
        day = ora.celebration_from_litcal(events, dt.date(2026, 9, 5))
        self.assertEqual(day["name"], "Saint Teresa of Calcutta, Virgin")
        self.assertEqual(day["rank"], "Optional Memorial")
        self.assertEqual(day["color"], "white")
        self.assertEqual(day["week"], "22")
        self.assertEqual(day["liturgicalYear"], "Year II")
        self.assertEqual(day["weekdayName"], "Saturday of the 22nd Week of Ordinary Time")
        self.assertEqual(day["alsoToday"], ["Saturday Memorial of the Blessed Virgin Mary"])
        self.assertEqual(day["vigil"], "23rd Sunday of Ordinary Time")

    def test_sunday_and_purple(self):
        events = [litcal_event("2026-03-15", "Fourth Sunday of Lent", 7, "rose", liturgical_year="YEAR A")]
        day = ora.celebration_from_litcal(events, dt.date(2026, 3, 15))
        self.assertEqual(day["rank"], "Sunday")
        self.assertEqual(day["color"], "rose")
        self.assertEqual(ora.normalize_color("purple"), "violet")

    def test_missing_date_falls_back(self):
        self.assertIsNone(ora.celebration_from_litcal([], dt.date(2026, 9, 2)))


class FeedTests(unittest.TestCase):
    def test_usccb_parsing(self):
        rss = """<rss><channel><item><title>Wednesday of the Twenty-second Week in Ordinary Time</title>
        <link>https://bible.usccb.org/bible/readings/090226.cfm</link>
        <description>&lt;h4&gt;Reading 1  &lt;a href="x"&gt;1 Corinthians 3:1-9&lt;/a&gt;&lt;/h4&gt;&lt;p&gt;text&lt;/p&gt;
        &lt;h4&gt;Responsorial Psalm  &lt;a href="x"&gt;Psalm 33:12-13, 14-15, 20-21&lt;/a&gt;&lt;/h4&gt;
        &lt;h4&gt;Alleluia  &lt;a href="x"&gt;Luke 4:18&lt;/a&gt;&lt;/h4&gt;
        &lt;h4&gt;Gospel  &lt;a href="x"&gt;Luke 4:38-44&lt;/a&gt;&lt;/h4&gt;</description></item></channel></rss>"""
        items = ora.parse_rss_items(rss.encode())
        self.assertEqual(len(items), 1)
        self.assertEqual(ora.usccb_date(items[0]["link"]), "2026-09-02")
        readings = ora.parse_readings(items[0]["description"])
        self.assertEqual([r["label"] for r in readings], ["Reading 1", "Psalm", "Alleluia", "Gospel"])
        self.assertEqual(readings[-1]["citation"], "Luke 4:38-44")
        # Only citations are kept; the copyrighted Lectionary text never leaves USCCB's page.
        self.assertNotIn("text", json.dumps(readings))

    def test_wordonfire_date(self):
        self.assertEqual(ora.wordonfire_date("Wednesday, September 2, 2026"), "2026-09-02")
        self.assertEqual(ora.wordonfire_date("Daily Gospel Reflections - Word on Fire"), "")


class PrayerTests(unittest.TestCase):
    def test_hours(self):
        self.assertEqual(ora.prayer_for(dt.datetime(2026, 9, 2, 7, 0), False)["key"], "morningOffering")
        self.assertEqual(ora.prayer_for(dt.datetime(2026, 9, 2, 12, 0), False)["key"], "angelus")
        self.assertEqual(ora.prayer_for(dt.datetime(2026, 9, 2, 12, 0), True)["key"], "reginaCaeli")
        self.assertEqual(ora.prayer_for(dt.datetime(2026, 9, 2, 15, 0), False)["key"], "memorare")
        self.assertEqual(ora.prayer_for(dt.datetime(2026, 9, 2, 18, 30), False)["slot"], "Evening")
        self.assertEqual(ora.prayer_for(dt.datetime(2026, 9, 2, 23, 0), False)["key"], "actOfContrition")


class PayloadTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = pathlib.Path(self.tmp.name)
        self.saved = (ora.STATE_DIR, ora.STATE_FILE, ora.CACHE_DIR, ora.FEEDS_FILE)
        ora.STATE_DIR = base / "state"
        ora.STATE_FILE = ora.STATE_DIR / "state.json"
        ora.CACHE_DIR = base / "cache"
        ora.FEEDS_FILE = ora.CACHE_DIR / "feeds.json"

    def tearDown(self):
        ora.STATE_DIR, ora.STATE_FILE, ora.CACHE_DIR, ora.FEEDS_FILE = self.saved
        self.tmp.cleanup()

    def test_offline_payload(self):
        payload = ora.today_payload(dt.date(2026, 8, 30))
        self.assertEqual(payload["source"], "builtin")
        self.assertEqual(payload["celebration"]["name"], "Ordinary Time")
        self.assertEqual(payload["links"]["readings"], "https://www.wordonfire.org/reflections/")
        self.assertEqual(payload["links"]["usccb"], "https://bible.usccb.org/bible/readings/083026.cfm")
        self.assertEqual(payload["links"]["rosary"], "https://www.usccb.org/how-to-pray-the-rosary")
        self.assertEqual(payload["mysteries"][0], "The Resurrection")
        self.assertEqual(payload["progress"], 0)
        self.assertEqual(len(payload["week"]), 7)
        self.assertTrue(payload["week"][-1]["isToday"])

    def test_cached_feeds_and_completion(self):
        ora.write_json(ora.FEEDS_FILE, {
            "fetched": "2026-09-02T08:00:00",
            "usccb": {"2026-09-02": {"title": "Wednesday", "link": "https://bible.usccb.org/bible/readings/090226.cfm",
                                     "readings": [{"label": "Gospel", "citation": "Luke 4:38-44"}]}},
            "wordonfire": {"2026-09-02": "https://www.wordonfire.org/reflections/a-ordinary2026-wk22-wednesday/"},
        })
        ora.set_completed("readings", True, dt.date(2026, 9, 1))
        ora.set_completed("rosary", True, dt.date(2026, 9, 2))
        payload = ora.today_payload(dt.datetime(2026, 9, 2, 12, 0))
        self.assertEqual(payload["gospel"], "Luke 4:38-44")
        self.assertEqual(payload["links"]["readings"], "https://www.wordonfire.org/reflections/a-ordinary2026-wk22-wednesday/")
        self.assertEqual(payload["progress"], 1)
        self.assertEqual(payload["streak"], 2)
        self.assertTrue(payload["week"][-1]["rosary"])
        self.assertTrue(payload["week"][-2]["readings"])

    def test_streak_survives_an_unfinished_today(self):
        state = {"2026-09-01": {"readings": True}, "2026-08-31": {"rosary": True}}
        self.assertEqual(ora.streak(state, dt.date(2026, 9, 2)), 2)
        self.assertEqual(ora.streak({}, dt.date(2026, 9, 2)), 0)


if __name__ == "__main__":
    unittest.main()
