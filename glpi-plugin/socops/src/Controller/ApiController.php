<?php

namespace GlpiPlugin\Socops\Controller;

use Glpi\Controller\AbstractController;
use Glpi\Http\Firewall;
use Glpi\Security\Attribute\SecurityStrategy;
use GlpiPlugin\Socops\TicketRepository;
use Session;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Attribute\Route;
use Ticket;

final class ApiController extends AbstractController
{
    #[Route('/api', name: 'socops_api', methods: ['GET'])]
    #[SecurityStrategy(Firewall::STRATEGY_NO_CHECK)]
    public function __invoke(Request $request): JsonResponse
    {
        if (Session::getLoginUserID() < 1) {
            return self::json(401, [
                'error' => 'Your GLPI session has expired. Sign in again to continue.',
            ]);
        }
        if (!Ticket::canView()) {
            return self::json(403, [
                'error' => 'Your GLPI profile does not allow access to tickets.',
            ]);
        }

        $action = (string) $request->query->get('action', 'overview');
        try {
            if ($action === 'overview') {
                return self::json(200, ['data' => TicketRepository::getOverview()]);
            }

            if ($action === 'tickets') {
                $view = (string) $request->query->get('view', 'incidents');
                if (!in_array($view, ['incidents', 'investigations', 'assigned'], true)) {
                    return self::json(400, ['error' => 'Choose a supported ticket view.']);
                }

                $filters = [
                    'view'     => $view,
                    'q'        => mb_substr((string) $request->query->get('q', ''), 0, 120),
                    'status'   => (string) $request->query->get('status', ''),
                    'severity' => (string) $request->query->get('severity', ''),
                    'start'    => (int) $request->query->get('start', 0),
                    'limit'    => (int) $request->query->get('limit', 25),
                ];

                return self::json(200, ['data' => TicketRepository::getTickets($filters)]);
            }

            if ($action === 'ticket') {
                $id = filter_var(
                    $request->query->get('id'),
                    FILTER_VALIDATE_INT
                );
                if ($id === false || $id === null) {
                    return self::json(400, ['error' => 'A valid ticket ID is required.']);
                }

                return self::json(200, [
                    'data' => TicketRepository::getTicket((int) $id),
                ]);
            }

            return self::json(404, [
                'error' => 'The requested SOC workspace action was not found.',
            ]);
        } catch (\InvalidArgumentException $error) {
            return self::json(400, ['error' => 'Choose a supported ticket view.']);
        } catch (\RuntimeException $error) {
            // Do not disclose whether an inaccessible ticket exists.
            return self::json(404, [
                'error' => 'The ticket was not found or is not available to your GLPI profile.',
            ]);
        } catch (\Throwable $error) {
            error_log('[socops] Request failed: ' . get_class($error));
            return self::json(500, [
                'error' => 'GLPI could not load this SOC data. Try again or open the ticket in GLPI.',
            ]);
        }
    }

    private static function json(int $status, array $data): JsonResponse
    {
        $response = new JsonResponse($data, $status);
        $response->headers->set('Cache-Control', 'no-store, private');
        $response->headers->set('X-Content-Type-Options', 'nosniff');

        return $response;
    }
}
