from prometheus_client import Counter, Histogram

REQUESTS = Counter("commerce_http_requests_total", "HTTP requests", ["method", "path", "status"])
REQUEST_DURATION = Histogram("commerce_http_request_duration_seconds", "HTTP request duration", ["method", "path"])
LOGIN_SUCCESS = Counter("commerce_login_success_total", "Successful logins")
LOGIN_FAILURE = Counter("commerce_login_failure_total", "Failed logins")
ORDERS_CREATED = Counter("commerce_orders_created_total", "Orders created")
