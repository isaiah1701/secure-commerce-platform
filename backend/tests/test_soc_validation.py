import importlib.util
from pathlib import Path
from types import SimpleNamespace

import pytest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("soc_validation", ROOT / "soc/validate.py")
VALIDATION = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATION)


@pytest.mark.parametrize(("title", "expected"), [
    ("Case — Sentinel incident 64", True),
    ("Case — Sentinel incident 64 - Investigation", True),
    ("Case — Sentinel incident 640", False),
    ("Case — Sentinel incident 640 - Investigation", False),
    ("Case [ed98fa83-ca86-4b08-9e33-045101eac088]", True),
    ("Unrelated case 64", False),
])
def test_incident_number_matching_has_boundaries(title, expected):
    assert VALIDATION.matches_ticket(title, "ed98fa83-ca86-4b08-9e33-045101eac088", 64) is expected


@pytest.mark.parametrize("details", [{"ScenarioId": ["soc-real"]}, '{"ScenarioId":["soc-real"]}', {"ScenarioId": "soc-real"}])
def test_real_connector_custom_detail_shapes(details):
    assert VALIDATION.detail_scenario({"properties": {"additionalData": {"Custom Details": details}}}) == "soc-real"


def test_missing_custom_details_do_not_match_unrelated_activity():
    assert VALIDATION.detail_scenario({}) == ""
    assert VALIDATION.detail_scenario({"properties": {"additionalData": {"Custom Details": {"ScenarioId": []}}}}) == ""


def test_invalid_glpi_search_fails_closed():
    client = VALIDATION.GLPIClient()
    response = SimpleNamespace(raise_for_status=lambda: None, json=lambda: {"unexpected": "response"})
    client.session = SimpleNamespace(get=lambda *args, **kwargs: response)
    with pytest.raises(ValueError, match="Invalid GLPI search"):
        client.tickets("ed98fa83-ca86-4b08-9e33-045101eac088", 64)


def test_real_glpi_zero_result_response_omits_data():
    assert VALIDATION.search_rows({"totalcount": 0, "count": 0, "content-range": "0--1/0"}) == []
    assert VALIDATION.search_rows({"totalcount": 1, "data": [{"1": "Case", "2": 54}]}) == [{"1": "Case", "2": 54}]
    for invalid in ({}, {"totalcount": 1}, {"totalcount": 1, "data": []}, {"totalcount": 0, "data": [{}]}, {"totalcount": -1}, []):
        with pytest.raises(ValueError):
            VALIDATION.search_rows(invalid)


def test_output_errors_do_not_disclose_signed_links(monkeypatch):
    monkeypatch.setattr(VALIDATION.requests, "get", lambda *args, **kwargs: SimpleNamespace(status_code=403))
    with pytest.raises(RuntimeError) as error:
        VALIDATION.fetch_output("https://example.invalid?sig=do-not-print")
    assert "HTTP 403" in str(error.value) and "do-not-print" not in str(error.value)


def test_run_scenario_does_not_persist_synthetic_credentials(monkeypatch, tmp_path, capsys):
    class TemporaryDirectory:
        def __enter__(self):
            self.path = tmp_path / "k6-temp"
            self.path.mkdir()
            return str(self.path)

        def __exit__(self, *args):
            for path in self.path.iterdir():
                path.unlink()
            self.path.rmdir()
            return False

    monkeypatch.setattr(VALIDATION.tempfile, "TemporaryDirectory", lambda **kwargs: TemporaryDirectory())
    monkeypatch.setattr(VALIDATION, "EVIDENCE", tmp_path / "evidence")
    monkeypatch.setattr(VALIDATION.requests, "get", lambda *args, **kwargs: SimpleNamespace(status_code=200))
    monkeypatch.setattr(VALIDATION.requests, "post", lambda *args, **kwargs: SimpleNamespace(status_code=201))
    monkeypatch.setattr(VALIDATION.time, "sleep", lambda *args: None)

    observed_password = []

    def fake_k6(command, env, **kwargs):
        summary_path = Path(command[command.index("--summary-export") + 1])
        summary_path.write_text('{"metrics":{"http_reqs":{"count":8},"checks":{"passes":8,"fails":0},"vus_max":{"max":1}}}')
        assert env["TEST_PASSWORD"] not in " ".join(command)
        observed_password.append(env["TEST_PASSWORD"])
        return SimpleNamespace(returncode=0, stderr="")

    monkeypatch.setattr(VALIDATION.subprocess, "run", fake_k6)

    assert VALIDATION.run_scenario("auth-lockout") == 0
    evidence = next((tmp_path / "evidence").glob("*.json")).read_text()
    output = capsys.readouterr().out
    assert '"credential_handling": "Passed to the k6 subprocess environment only; not persisted"' in evidence
    assert "TEST_PASSWORD" not in evidence
    assert observed_password[0] not in output
    assert sorted(path.name for path in tmp_path.iterdir()) == ["evidence"]
