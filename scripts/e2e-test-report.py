"""Render a pass/fail summary from the JUnit file a test run leaves behind.

Both E2E assertion modes invoke the driver directly, so every invocation boots a
fresh VM. The artifact provides a concise result without scraping terminal
output and survives a failed assertion long enough to report its details.

Takes one or more paths: either a test output directory or the `tests`
aggregate containing several.
"""

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

GREEN, RED, DIM, BOLD, OFF = "\033[32m", "\033[31m", "\033[2m", "\033[1m", "\033[0m"


def reports(root: Path):
    """Find each JUnit file with its recorded exit status and wall time.

    The native logger omits per-subtest timings, so the invoking recipe records
    the useful measurement: wall time around the complete driver process.
    """
    for d in sorted(p for p in [root, *root.iterdir()] if p.is_dir()):
        status_file = d / "status"
        if not status_file.exists():
            continue
        status = int(status_file.read_text().strip() or 1)
        xml = d / "junit.xml"
        wall_file = d / "wall-nanoseconds"
        wall = (
            int(wall_file.read_text().strip()) / 1_000_000_000
            if wall_file.exists()
            else None
        )
        yield d.name, (xml if xml.exists() else None), status, wall


def cases(path: Path):
    for tc in ET.parse(path).getroot().iter("testcase"):
        name = tc.get("name", "?")
        # The driver wraps the entire script as a case called "main" alongside
        # the real subtests. It is bookkeeping, not an assertion, and counting
        # it inflates every total.
        if name == "main":
            continue
        failure = tc.find("failure")
        if failure is None:
            failure = tc.find("error")
        # Distinguish "took no measurable time" from "no timing recorded". The
        # driver's JunitXMLLogger omits the attribute entirely even though its
        # terminal output prints the duration, so rendering that as 0.00s would
        # be inventing a measurement.
        raw = tc.get("time")

        detail = None
        if failure is not None:
            detail = failure.get("message") or failure.text or "failed"
            # The driver's JunitXMLLogger hardcodes add_failure_info("test case
            # failed"), which says nothing. The real message is appended to the
            # case's stderr by error(), so prefer that when the message is the
            # useless constant.
            if detail.strip() == "test case failed":
                err = tc.find("system-err")
                text = (err.text or "").strip() if err is not None else ""
                interesting = [
                    line
                    for line in text.splitlines()
                    if line.strip() and not line.startswith("Traceback")
                ]
                if interesting:
                    detail = "\n".join(interesting[-3:])

        yield (name, None if raw is None else float(raw), detail)


def elide(name: str, width: int) -> str:
    """Keep both ends of a long name; the middle of a parametrised id is the
    least informative part."""
    if len(name) <= width:
        return name
    keep = width - 3
    return name[: keep // 2] + "..." + name[-(keep - keep // 2) :]


def main(argv: list[str]) -> int:
    total = failed = 0
    wall_total = 0.0
    wall_reports = 0
    suites = 0

    for arg in argv:
        for name, xml, status, wall in reports(Path(arg)):
            suites += 1
            if wall is not None:
                wall_total += wall
                wall_reports += 1
            # Building a single test passes a raw store path, so strip the
            # hash and the framework's prefix to keep suite names readable.
            label = re.sub(r"^[a-z0-9]{32}-", "", name)
            label = re.sub(r"^vm-test-run-", "", label)
            print(f"{BOLD}== {label} =={OFF}")

            if xml is None:
                # The driver died before its atexit hook could write a report.
                # That is an infrastructure failure, not a test result, and
                # saying so is more useful than reporting zero tests.
                failed += 1
                print(f"  {RED}ERROR{OFF} no report written (driver exited {status})")
                continue

            marked = 0
            for case, seconds, failure in cases(xml):
                total += 1
                took = "" if seconds is None else f" {DIM}{seconds:6.2f}s{OFF}"
                verdict = f"{RED}FAIL{OFF}" if failure else f"{GREEN}PASS{OFF}"
                print(f"  {verdict}  {elide(case, 56):<56}{took}")
                if failure:
                    marked += 1
                    for line in failure.strip().splitlines()[:6]:
                        print(f"        {RED}{line}{OFF}")
            failed += marked

            # The recorded exit status is the authority. If it is non-zero but
            # no case was marked, the report is lying by omission -- say so
            # rather than printing a green summary over a failed run.
            if status != 0 and marked == 0:
                failed += 1
                print(f"  {RED}FAIL{OFF}  run exited {status} with no case marked failed")

    if not suites:
        print("no junit reports found", file=sys.stderr)
        return 1

    colour = RED if failed else GREEN
    timing = (
        f"{wall_total:.1f}s wall"
        if wall_reports == suites
        else "wall time unavailable"
    )
    print(
        f"\n{colour}{suites} suite(s)  {total} test(s)  "
        f"{failed} failed{OFF}  {DIM}{timing}{OFF}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
