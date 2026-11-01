import argparse
import hashlib
import json
import os
import secrets
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = "/subscriptions/43adc2c2-0fd5-4474-aa8a-9f32f541e4b7/resourceGroups/secure-commerce-dev-rg/providers/Microsoft.OperationalInsights/workspaces/secure-commerce-dev-law"
WORKFLOW = "/subscriptions/43adc2c2-0fd5-4474-aa8a-9f32f541e4b7/resourceGroups/secure-commerce-dev-rg/providers/Microsoft.Logic/workflows/secure-commerce-dev-soc-glpi-playbook"
CUSTOMER_ID = "a2d52d68-fcce-47a5-bcfe-e7236b57da79"
GLPI = "https://ticket.platf0rm.site"
EVIDENCE = ROOT / "docs/soc/evidence"


def azure(*args):
    result = subprocess.run(["az", *args, "-o", "json", "--only-show-errors"], capture_output=True, text=True, timeout=90, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else None


@lru_cache(maxsize=1)
def management_token():
    return azure("account", "get-access-token", "--resource", "https://management.azure.com/")["accessToken"]


def rest(resource, method="get", version="2019-05-01"):
    response = requests.request(method, f"https://management.azure.com{resource}?api-version={version}", headers={"Authorization": f"Bearer {management_token()}"}, timeout=60)
    response.raise_for_status()
    return response.json() if response.content else {}


def query(kql):
    return azure("monitor", "log-analytics", "query", "-w", CUSTOMER_ID, "--analytics-query", kql)


def secret(name):
    return azure("keyvault", "secret", "show", "--vault-name", "secure-commerce-dev-43ad", "--name", name)["value"]


def write_evidence(name, data):
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    destination = EVIDENCE / f"{name}.json"
    destination.write_text(json.dumps(data, indent=2) + "\n")
    return destination


def matches_ticket(title, guid, number):
    return guid in title or title.endswith(f"Sentinel incident {number}") or f"Sentinel incident {number} - " in title


def search_rows(result):
    count = result.get("totalcount") if isinstance(result, dict) else None
    rows = result.get("data", []) if count == 0 else result.get("data") if isinstance(result, dict) else None
    if type(count) is not int or count < 0 or not isinstance(rows, list) or (count == 0) != (len(rows) == 0):
        raise ValueError("Invalid GLPI search response")
    return rows


class GLPIClient:
    def __enter__(self):
        self.session = requests.Session()
        self.session.headers["App-Token"] = secret("soc-glpi-app-token")
        response = self.session.get(f"{GLPI}/apirest.php/initSession/", auth=(secret("soc-glpi-api-username"), secret("soc-glpi-api-password")), timeout=30)
        response.raise_for_status()
        self.session.headers["Session-Token"] = response.json()["session_token"]
        return self

    def __exit__(self, *args):
        self.session.delete(f"{GLPI}/apirest.php/killSession/", timeout=15)
        self.session.close()

    def tickets(self, guid, number):
        params = {"criteria[0][field]": 1, "criteria[0][searchtype]": "contains", "criteria[0][value]": guid,
                  "criteria[1][field]": 1, "criteria[1][searchtype]": "contains", "criteria[1][value]": f"Sentinel incident {number}", "criteria[1][link]": "OR"}
        response = self.session.get(f"{GLPI}/apirest.php/search/Ticket/", params=params, timeout=30)
        response.raise_for_status()
        result = response.json()
        tickets = []
        for item in search_rows(result):
            if matches_ticket(item["1"], guid, number):
                ticket = self.session.get(f"{GLPI}/apirest.php/Ticket/{item['2']}", timeout=30)
                ticket.raise_for_status()
                tickets.append(ticket.json())
        return tickets


def fetch_output(uri):
    try:
        response = requests.get(uri, timeout=30)
    except requests.RequestException:
        raise RuntimeError("Logic App output retrieval failed; signed URL withheld") from None
    if response.status_code != 200:
        raise RuntimeError(f"Logic App output retrieval returned HTTP {response.status_code}; signed URL withheld")
    return response.json()


def linked_output(resource):
    metadata = rest(resource)
    return fetch_output(metadata["properties"]["outputsLink"]["uri"])


def detail_scenario(alert):
    details = alert.get("properties", {}).get("additionalData", {}).get("Custom Details", {})
    if isinstance(details, str):
        details = json.loads(details)
    value = details.get("ScenarioId", "")
    return (value[0] if value else "") if isinstance(value, list) else value


def run_scenario(scenario, user=None, password_secret=None):
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    scenario_id = f"soc-{scenario}-{stamp}"
    password = secret(password_secret) if password_secret else f"Soc!{secrets.token_urlsafe(22)}9a"
    prefix = "soc-spray" if scenario == "password-spray" else "soc"
    accounts = [user] if user else [f"{prefix}-{stamp.lower()}-{index}@platf0rm.site" for index in range(5 if scenario == "password-spray" else 1)]
    if not user:
        for attempt in range(2):
            try:
                response = requests.get("https://shop.platf0rm.site/ready", timeout=60)
                if response.status_code == 200:
                    break
            except requests.RequestException:
                if attempt:
                    raise
            time.sleep(1)
        else:
            raise RuntimeError("Owned lab did not become ready; no scenario activity sent")
        for email in accounts:
            response = requests.post("https://shop.platf0rm.site/api/auth/register", json={"email": email, "password": password, "first_name": "SOC", "last_name": "Synthetic"}, headers={"X-SOC-Scenario-ID": f"{scenario_id}-provision", "X-Request-ID": f"{scenario_id}-new-{accounts.index(email)}"}, timeout=30)
            if response.status_code != 201:
                raise RuntimeError(f"Synthetic registration returned {response.status_code}; stopped")
            time.sleep(1)
    environment = dict(os.environ, SCENARIO=scenario, SCENARIO_ID=scenario_id, BASE_URL="https://shop.platf0rm.site", TEST_USER=accounts[0], TEST_USERS=",".join(accounts), TEST_PASSWORD=password, ATTEMPTS="8")
    with tempfile.TemporaryDirectory(prefix="soc-k6-") as directory:
        summary_path = Path(directory) / "summary.json"
        script = ROOT / "soc/k6/password-spray.js" if scenario == "password-spray" else ROOT / "soc/k6/scenarios.js"
        result = subprocess.run(["k6", "run", "--quiet", "--summary-export", str(summary_path), str(script)], env=environment, capture_output=True, text=True, timeout=260, check=False)
        summary = json.loads(summary_path.read_text()) if summary_path.exists() else {}
    metrics = summary.get("metrics", {})
    evidence = {"scenario": scenario, "simulation_id": scenario_id, "executed_utc": stamp, "k6_exit_code": result.returncode, "requests": metrics.get("http_reqs", {}).get("count"), "checks_passed": metrics.get("checks", {}).get("passes"), "checks_failed": metrics.get("checks", {}).get("fails"), "max_vus": metrics.get("vus_max", {}).get("max"), "credential_handling": "Passed to the k6 subprocess environment only; not persisted"}
    if result.returncode:
        evidence["execution_error"] = result.stderr[-1500:]
    print(json.dumps({"evidence": str(write_evidence(scenario_id, evidence)), **evidence}), flush=True)
    return result.returncode


def verify(scenario_id, wait):
    destination = EVIDENCE / f"{scenario_id}.json"
    evidence = json.loads(destination.read_text()) if destination.exists() else {"simulation_id": scenario_id}
    deadline = time.monotonic() + wait
    checked_runs = set()
    while True:
        evidence["telemetry"] = query("ContainerAppConsoleLogs_CL | where TimeGenerated > ago(1d) | extend p=parse_json(Log_s) | where tostring(p.simulation_id)==" + json.dumps(scenario_id) + " | summarize Events=count(),Requests=dcount(tostring(p.request_id)),FirstActivityUtc=min(todatetime(p.timestamp)),LastActivityUtc=max(todatetime(p.timestamp)),ObservedSources=make_set(tostring(p.source_ip)),Accounts=make_set(tostring(p.email_hash)) by EventType=tostring(p.event_type)")
        runs = rest(f"{WORKFLOW}/runs")["value"]
        for run in runs[:50]:
            if run["properties"]["status"] != "Succeeded":
                continue
            run_id = run["name"]
            if run_id in checked_runs:
                continue
            checked_runs.add(run_id)
            trigger = run["properties"].get("trigger", {})
            incident = fetch_output(trigger["outputsLink"]["uri"]).get("body", {}).get("object", {})
            properties = incident.get("properties", {})
            alerts = [alert for alert in properties.get("alerts", []) if detail_scenario(alert) == scenario_id]
            if not alerts:
                continue
            actions = rest(f"{WORKFLOW}/runs/{run_id}/actions")["value"]
            if not any(item["name"] in ("Create_GLPI_Ticket", "Create_GLPI_BruteForce_Ticket") and item["properties"]["status"] == "Succeeded" for item in actions):
                continue
            guid = incident.get("name", incident["id"].rsplit("/", 1)[-1])
            number = properties["incidentNumber"]
            with GLPIClient() as client:
                tickets = client.tickets(guid, number)
            if len(tickets) != 1:
                raise RuntimeError(f"Incident {number}: expected one ticket, found {len(tickets)}")
            ticket = tickets[0]
            content = ticket["content"]
            evidence["chain"] = {"incident_id": guid, "incident_number": number, "severity": properties["severity"], "alert_ids": [alert["properties"]["systemAlertId"] for alert in alerts], "rule_ids": properties.get("relatedAnalyticRuleIds"), "logic_app_run": run_id, "logic_app_status": run["properties"]["status"], "actions": {item["name"]: item["properties"]["status"] for item in actions}, "ticket_id": ticket["id"], "ticket_url": f"{GLPI}/front/ticket.form.php?id={ticket['id']}", "ticket_count": len(tickets), "ticket_contains_incident_id": guid in content, "ticket_contains_scenario_id": scenario_id in content, "ticket_sections": all(section in content for section in ("Incident Summary", "Investigation Objective", "Investigation Steps", "Definition of Done")), "ticket_links": 'href="https://portal.azure.com/' in content and "workspaces/secure-commerce-dev-law/overview" in content, "ticket_content_sha256": hashlib.sha256(content.encode()).hexdigest()}
            evidence["chain"]["log_analytics_result"] = linked_output(f"{WORKFLOW}/runs/{run_id}/actions/Query_Commerce_Evidence").get("body", {}).get("tables", [])
            tables = evidence["chain"]["log_analytics_result"]
            evidence["chain"]["observed_evidence_present"] = bool(tables and tables[0].get("rows") and tables[0]["rows"][0][4] > 0 and evidence["telemetry"])
            evidence["chain"]["automatic_creation_succeeded"] = any(item["name"] in ("Create_GLPI_Ticket", "Create_GLPI_BruteForce_Ticket") and item["properties"]["status"] == "Succeeded" for item in actions)
            evidence["status"] = "VERIFIED" if all((evidence.get("k6_exit_code") == 0, run["properties"]["status"] == "Succeeded", evidence["chain"]["ticket_contains_incident_id"], evidence["chain"]["ticket_contains_scenario_id"], evidence["chain"]["ticket_sections"], evidence["chain"]["ticket_links"], evidence["chain"]["observed_evidence_present"], evidence["chain"]["automatic_creation_succeeded"])) else "IMPLEMENTED BUT UNTESTED"
            write_evidence(scenario_id, evidence)
            print(json.dumps({"simulation_id": scenario_id, "status": evidence["status"], **{key: evidence["chain"][key] for key in ("incident_id", "incident_number", "logic_app_run", "ticket_id", "ticket_url", "ticket_count")}}), flush=True)
            return 0 if evidence["status"] == "VERIFIED" else 1
        write_evidence(scenario_id, evidence)
        if time.monotonic() >= deadline:
            print(json.dumps({"simulation_id": scenario_id, "status": "IMPLEMENTED BUT UNTESTED", "telemetry_rows": len(evidence["telemetry"]), "blocker": "Matching Sentinel-to-GLPI execution not observed before deadline"}), flush=True)
            return 1
        print(f"{scenario_id}: telemetry rows={len(evidence['telemetry'])}; awaiting correlated Sentinel and Logic App evidence", flush=True)
        time.sleep(min(30, max(0, deadline - time.monotonic())))


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    execution = commands.add_parser("run")
    execution.add_argument("scenario", choices=("auth-lockout", "password-spray", "auth-success-after-failures", "registration-abuse", "privilege-probe", "admin-directory", "suspicious-api", "auth-rate-limit"))
    execution.add_argument("--user")
    execution.add_argument("--password-secret")
    verification = commands.add_parser("verify")
    verification.add_argument("scenario_id")
    verification.add_argument("--wait", type=int, default=0)
    args = parser.parse_args()
    return run_scenario(args.scenario, args.user, args.password_secret) if args.command == "run" else verify(args.scenario_id, args.wait)


if __name__ == "__main__":
    sys.exit(main())
