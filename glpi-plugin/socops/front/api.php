<?php
use GlpiPlugin\Socops\TicketRepository;

require_once dirname(__DIR__, 3) . '/inc/includes.php';

header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');

function socops_json_response(int $status, array $data): never
{
    http_response_code($status);
    echo json_encode($data, JSON_INVALID_UTF8_SUBSTITUTE | JSON_UNESCAPED_SLASHES);
    exit;
}

if (Session::getLoginUserID() < 1) {
    socops_json_response(401, ['error' => 'Your GLPI session has expired. Sign in again to continue.']);
}
if (!Ticket::canView()) {
    socops_json_response(403, ['error' => 'Your GLPI profile does not allow access to tickets.']);
}
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
    socops_json_response(405, ['error' => 'This endpoint accepts read-only GET requests.']);
}

$action = (string) ($_GET['action'] ?? 'overview');
if ($action === 'tickets' && !in_array(
    (string) ($_GET['view'] ?? 'incidents'),
    ['incidents', 'investigations', 'assigned'],
    true
)) {
    socops_json_response(400, ['error' => 'Choose a supported ticket view.']);
}

try {
    if ($action === 'overview') {
        socops_json_response(200, ['data' => TicketRepository::getOverview()]);
    }
    if ($action === 'tickets') {
        $filters = [
            'view'     => (string) ($_GET['view'] ?? 'incidents'),
            'q'        => mb_substr((string) ($_GET['q'] ?? ''), 0, 120),
            'status'   => (string) ($_GET['status'] ?? ''),
            'severity' => (string) ($_GET['severity'] ?? ''),
            'start'    => (int) ($_GET['start'] ?? 0),
            'limit'    => (int) ($_GET['limit'] ?? 25),
        ];
        socops_json_response(200, ['data' => TicketRepository::getTickets($filters)]);
    }
    if ($action === 'ticket') {
        $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
        if ($id === false || $id === null) {
            socops_json_response(400, ['error' => 'A valid ticket ID is required.']);
        }
        socops_json_response(200, ['data' => TicketRepository::getTicket((int) $id)]);
    }

    socops_json_response(404, ['error' => 'The requested SOC workspace action was not found.']);
} catch (\RuntimeException $error) {
    // Ticket access and other per-item errors should not disclose ticket data.
    socops_json_response(404, ['error' => 'The ticket was not found or is not available to your GLPI profile.']);
} catch (\Throwable $error) {
    error_log('[socops] Request failed: ' . get_class($error));
    socops_json_response(500, ['error' => 'GLPI could not load this SOC data. Try again or open the ticket in GLPI.']);
}
