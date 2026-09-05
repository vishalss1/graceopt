"""Tests for statistical claims, checksum gating and test pipeline integrity."""
import json
import math
from pathlib import Path
from types import SimpleNamespace
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "test"))
from bench_sample import collect, execute
from bench_stats import describe, compare
from report import rows
from run_tests import split_pipeline, run_test
from workloads import VARIANTS


class StatisticsTests(unittest.TestCase):
    def test_no_difference_is_inconclusive(self):
        self.assertEqual(compare([1, 1, 1], [1, 1, 1])["verdict"], "inconclusive")

    def test_known_speedup_and_regression(self):
        self.assertEqual(compare([2, 2, 2], [1, 1, 1])["speedup"], 2)
        self.assertEqual(compare([1, 1, 1], [2, 2, 2])["verdict"], "slower")

    def test_bootstrap_is_reproducible(self):
        self.assertEqual(compare([1, 2, 3], [1, 1, 2]), compare([1, 2, 3], [1, 1, 2]))

    def test_reject_bad_samples(self):
        for values in ([], [0], [-1], [math.nan], [math.inf]):
            with self.assertRaises(ValueError): describe(values)
        with self.assertRaises(ValueError): compare([1], [1])
        with self.assertRaises(ValueError): compare([1, 2], [1, 2, 3])

    def test_median_and_dispersion(self):
        result = describe([1, 2, 3])
        self.assertEqual(result["median"], 2)
        self.assertEqual(result["mad"], 1)
        self.assertEqual(result["cv"], .5)


class SamplingTests(unittest.TestCase):
    @patch("bench_sample.execute")
    def test_checksum_mismatch_stops_measurement(self, mocked):
        mocked.side_effect = [{"seconds": .1, "checksum": 1},
                              {"seconds": .1, "checksum": 99}]
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            collect([{"name": "stock", "executable": "unused"}], 1, 2, .1, 2, 5, 42)

    @patch("bench_sample.execute")
    def test_all_rounds_have_every_variant(self, mocked):
        mocked.return_value = {"seconds": .01, "checksum": 1}
        result = collect([{"name": n, "executable": n} for n in ("stock", "grace")],
                         10, 5, .02, 2, 5, 42)
        self.assertEqual(result["repetitions"], 2)
        self.assertEqual(len(result["samples"]["grace"]), 5)
        self.assertTrue(all(set(order) == {"stock", "grace"} for order in result["execution_order"]))
        self.assertGreater(len({tuple(order) for order in result["execution_order"]}), 1)

    @patch("bench_sample.command")
    def test_reject_nonfinite_and_inconsistent_output(self, mocked):
        for seconds, size, checksum in [(0, 4, 1), (float("inf"), 4, 1), (.1, 99, 1), (.1, 4, float("nan"))]:
            mocked.return_value = (1, SimpleNamespace(stdout=json.dumps(
                {"size": size, "repetitions": 2, "seconds": seconds, "checksum": checksum})))
            with self.assertRaises(ValueError): execute("unused", 4, 2, 1, 5)

    def test_matching_variants_share_optimization_flags(self):
        for stock, grace in [("stock", "grace"), ("stock-o3", "grace-o3"), ("stock-scalar", "grace-scalar")]:
            self.assertEqual(VARIANTS[stock].flags, VARIANTS[grace].flags)


class IntegrityTests(unittest.TestCase):
    def test_incomplete_report_is_rejected(self):
        with self.assertRaises(ValueError): list(rows({"schema_version": 1, "complete": False}))

    def test_quoted_pipes_are_not_stages(self):
        self.assertEqual(split_pipeline('first "a|b" | second'), ['first "a|b"', 'second'])

    def test_failed_producer_is_not_hidden(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "failure.ll"
            path.write_text(f'; RUN: "{sys.executable}" -c "import sys; sys.exit(7)" | "{sys.executable}" -c "pass"\n')
            tc = SimpleNamespace(opt="unused", clang="unused", plugin="unused")
            ok, log = run_test(path, tc, Path(td), False)
            self.assertFalse(ok)
            self.assertIn("exit code 7", log)


if __name__ == "__main__":
    unittest.main()
