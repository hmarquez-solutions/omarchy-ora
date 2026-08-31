import datetime as dt
import importlib.machinery
import importlib.util
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("ora", str(ROOT / "ora"))
spec = importlib.util.spec_from_loader(loader.name, loader)
ora = importlib.util.module_from_spec(spec)
loader.exec_module(ora)


class OraTests(unittest.TestCase):
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

    def test_rosary_cycle(self):
        self.assertEqual(ora.mysteries(dt.date(2026, 8, 31))[0], "Joyful Mysteries")
        self.assertEqual(ora.mysteries(dt.date(2026, 9, 3))[0], "Luminous Mysteries")
        self.assertEqual(len(ora.mysteries(dt.date(2026, 9, 4))[1]), 5)

    def test_readings_url(self):
        payload = ora.today_payload(dt.date(2026, 8, 30))
        self.assertEqual(payload["links"]["readings"], "https://bible.usccb.org/bible/readings/083026.cfm")


if __name__ == "__main__":
    unittest.main()
