import logging
from types import SimpleNamespace

import pytest
from starlette.datastructures import Address

from app.core.config import get_settings
from app.lab_accounts import provision
from app.observability.logging import source_ip


def test_provisioning_is_restricted_and_idempotent(caplog):
    with caplog.at_level(logging.INFO, logger="secure_commerce"):
        created = provision("soc-admin-test@platf0rm.site", "SyntheticOnly!2026", "admin")
    assert created["role"] == "admin" and created["created"]
    assert not provision("soc-admin-test@platf0rm.site", "SyntheticOnly!2026", "admin")["created"]
    with pytest.raises(ValueError):
        provision("soc-admin-test@platf0rm.site", "ChangedSecret!2026", "admin")
    with pytest.raises(ValueError):
        provision("real-user@platf0rm.site", "SyntheticOnly!2026", "admin")
    assert "SyntheticOnly!2026" not in caplog.text


@pytest.mark.parametrize(("peer", "forwarded", "trusted", "expected"), [
    ("100.100.0.107", "8.8.8.8, 82.9.130.188", "100.64.0.0/10", "82.9.130.188"),
    ("100.100.0.107", "8.8.8.8, 100.100.0.108", "100.64.0.0/10", "unknown"),
    ("100.100.0.107", "", "100.64.0.0/10", "unknown"),
    ("82.9.130.188", "8.8.8.8", "100.64.0.0/10", "82.9.130.188"),
    ("127.0.0.1", "invalid", "127.0.0.0/8", "unknown"),
])
def test_source_attribution_rejects_private_and_untrusted_forwarders(monkeypatch, peer, forwarded, trusted, expected):
    monkeypatch.setattr(get_settings(), "trusted_proxy_cidrs", trusted)
    request = SimpleNamespace(client=Address(peer, 443), headers={"x-forwarded-for": forwarded})
    assert source_ip(request) == expected
