import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = (ROOT / "infra/modules/soar/workflow-actions.json.tftpl").read_text()
ACTIONS = json.loads(re.sub(r"\$\{\w+\}", "lab-placeholder", TEMPLATE))
SOC = (ROOT / "infra/modules/soc/main.tf").read_text()


def ticket_actions():
    route = ACTIONS["Create_GLPI_Ticket_If_Missing"]["actions"]["Route_GLPI_Ticket_By_Alert_Type"]
    return [route["actions"]["Create_GLPI_BruteForce_Ticket"], route["else"]["actions"]["Create_GLPI_Ticket"]]


def test_ticket_posts_are_not_automatically_retried_and_credentials_are_hidden():
    for action in ticket_actions():
        assert action["inputs"]["retryPolicy"] == {"type": "none"}
        assert action["runtimeConfiguration"]["secureData"]["properties"] == ["inputs", "outputs"]
        assert "triggerBody()?['object']?['name']" in action["inputs"]["body"]["input"]["name"]
    assert "Validate_Incident" in ACTIONS["Get_GLPI_API_Password"]["runAfter"]
    assert "Validate_GLPI_Search" in ACTIONS["Filter_Existing_GLPI_Tickets"]["runAfter"]
    invalid = ACTIONS["Validate_GLPI_Search"]["else"]["actions"]
    assert invalid["Close_Invalid_Search_Session"]["inputs"]["method"] == "DELETE"
    assert "Close_Invalid_Search_Session" in invalid["Reject_Invalid_Search"]["runAfter"]
    predicate = ACTIONS["Filter_Existing_GLPI_Tickets"]["inputs"]["where"]
    assert "endsWith" in predicate and "' - '" in predicate
    assert "@length(body('Filter_Existing_GLPI_Tickets'))" in str(ACTIONS["Create_GLPI_Ticket_If_Missing"]["expression"])


def test_tickets_have_actionable_sections_and_workspace_scoped_links():
    for action in ticket_actions():
        content = action["inputs"]["body"]["input"]["content"]
        for field in ("Incident Summary", "Severity", "Observed activity", "Affected asset", "Correlation ID", "Observed source", "Investigation Objective", "Investigation Steps", "Definition of Done"):
            assert field in content
        assert content.count("<li>") >= 9
        assert 'href="https://portal.azure.com/#@' in content
        assert "/overview" in content
        assert "LogsBlade" not in content and "Log_s" not in content
        assert "['tables']?[0]?['rows']?[0]?[0]" in content


def test_enrichment_is_scoped_to_alert_correlation_and_uses_emitted_time():
    query = ACTIONS["Query_Commerce_Evidence"]["inputs"]["body"]["query"]
    assert "Custom Details" in query and "details.ScenarioId" in query
    assert "tostring(payload.simulation_id)==scenario_id" in query
    assert "isnotempty(scenario_id)" in query
    assert "todatetime(payload.timestamp)" in query
    assert "payload.source_ip" in query and "make_set_if" in query
    assert "ipv4_is_in_any_range" in query and "100.64.0.0/10" in query
    assert "make_set_if(SourceIP" in query
    assert '"unknown"' in query and "multiple (review Log Analytics)" in query
    assert '"Unavailable"' in query


def test_correlated_rules_group_overlapping_results_and_count_distinct_requests():
    assert 'by_custom_details       = ["ScenarioId"]' in SOC
    assert 'lookback_duration       = "PT5H"' in SOC
    assert 'aggregation_method = "AlertPerResult"' in SOC
    for name in ("auth-attack", "auth-spray", "registration", "admin-activity", "privilege-probe", "success-after-failures", "api-abuse", "suspicious-request", "rate-limit"):
        query = (ROOT / f"infra/modules/soc/queries/{name}.kql").read_text()
        assert "SimulationId" in query
        assert "FirstActivityUtc" in query
    privilege = (ROOT / "infra/modules/soc/queries/privilege-probe.kql").read_text()
    assert "dcount(RequestId)" in privilege and 'EventType == "AUTH_FORBIDDEN"' in privilege
    success = (ROOT / "infra/modules/soc/queries/success-after-failures.kql").read_text()
    assert "on SimulationId, TargetHash" in success and "ActivityTime > FailureLast" in success


def test_trigger_serializes_duplicate_deliveries():
    terraform = (ROOT / "infra/modules/soar/main.tf").read_text()
    assert "concurrency = { runs = 1 }" in terraform
