<?php

namespace GlpiPlugin\Socops;

use CommonITILObject;
use CommonITILActor;
use KnowbaseItem;
use Search;
use Session;
use Ticket;
use User;

/**
 * Reads GLPI data through its native search and ticket classes.
 *
 * Search::getDatas applies GLPI's entity and ticket visibility rules before
 * returning rows. Ticket details and timeline items are checked again through
 * the item's own ACL methods.
 */
final class TicketRepository
{
    private const SUMMARY_LIMIT = 500;

    private const TICKET_FIELDS = [
        'name',
        'date',
        'date_mod',
        'closedate',
        'content',
        'status',
        'priority',
        'urgency',
        'impact',
        'solution',
        'users_id_recipient',
    ];

    /** @var array<string, int>|null */
    private static ?array $optionIds = null;

    /**
     * Return live counts and charts for tickets the current analyst can see.
     */
    public static function getOverview(): array
    {
        $result = self::search([], 0, self::SUMMARY_LIMIT);
        $tickets = $result['tickets'];
        $securityCases = array_values(array_filter(
            $tickets,
            static fn (array $ticket): bool => $ticket['isSocCase']
        ));
        $openCases = array_values(array_filter(
            $securityCases,
            static fn (array $ticket): bool => !in_array($ticket['status'], [
                Ticket::SOLVED,
                Ticket::CLOSED,
            ], true)
        ));

        $severity = [
            'critical' => 0,
            'high'     => 0,
            'medium'   => 0,
            'low'      => 0,
            'unknown'  => 0,
        ];
        $statusDistribution = [];
        $trend = self::emptyTrend();
        $workload = [];

        foreach ($securityCases as $ticket) {
            $key = $ticket['severity'] ?? 'unknown';
            if (!array_key_exists($key, $severity)) {
                $key = 'unknown';
            }
            $severity[$key]++;
            $statusLabel = $ticket['statusLabel'];
            $statusDistribution[$statusLabel] = ($statusDistribution[$statusLabel] ?? 0) + 1;

            $day = substr((string) $ticket['date'], 0, 10);
            if (isset($trend[$day])) {
                $trend[$day]++;
            }

            if (!empty($ticket['assignees'])) {
                if (!in_array($ticket['status'], [Ticket::SOLVED, Ticket::CLOSED], true)) {
                    foreach ($ticket['assignees'] as $assignee) {
                        $name = $assignee['name'];
                        if ($name !== '') {
                            $workload[$name] = ($workload[$name] ?? 0) + 1;
                        }
                    }
                }
            }
        }

        arsort($workload);
        $recentActivity = $securityCases;
        usort(
            $recentActivity,
            static fn (array $left, array $right): int =>
                strcmp((string) $right['dateMod'], (string) $left['dateMod'])
        );

        $now = new \DateTimeImmutable('now', new \DateTimeZone('UTC'));
        $thirtyDaysAgo = $now->modify('-30 days')->format('Y-m-d H:i:s');
        $resolved = count(array_filter(
            $securityCases,
            static fn (array $ticket): bool =>
                $ticket['status'] === Ticket::SOLVED
                && (string) $ticket['dateMod'] >= $thirtyDaysAgo
        ));

        return [
            'generatedAt'      => gmdate(DATE_ATOM),
            'currentUser'      => (string) ($_SESSION['glpiname'] ?? ''),
            'currentUserId'    => (int) ($_SESSION['glpiID'] ?? 0),
            'openCases'        => count($openCases),
            'awaitingTriage'   => count(array_filter(
                $openCases,
                static fn (array $ticket): bool => $ticket['status'] === Ticket::INCOMING
            )),
            'assignedCases'    => count(array_filter(
                $openCases,
                static fn (array $ticket): bool => $ticket['assignees'] !== []
            )),
            'resolvedLast30d'  => $resolved,
            'severity'         => $severity,
            'statusDistribution' => $statusDistribution,
            'trend'            => array_map(
                static fn (string $date, int $count): array => [
                    'date'  => $date,
                    'count' => $count,
                ],
                array_keys($trend),
                array_values($trend)
            ),
            'workload'         => array_map(
                static fn (string $name, int $count): array => [
                    'name'  => $name,
                    'count' => $count,
                ],
                array_keys($workload),
                array_values($workload)
            ),
            'recentActivity'   => array_slice($recentActivity, 0, 8),
            'totalVisibleTickets' => $result['total'],
            'sampled'          => $result['total'] > count($tickets),
            'sampleSize'       => count($tickets),
            'capabilities'     => [
                'assets'          => Session::haveRight('computer', READ),
                'knowledgeBase'   => class_exists(KnowbaseItem::class) && KnowbaseItem::canView(),
                'administration'  => Session::haveRight('config', UPDATE),
            ],
        ];
    }

    /**
     * Return an ACL-filtered, searchable queue.
     *
     * @param array<string, string|int> $filters
     * @return array{tickets: array, total: int, start: int, limit: int, currentUserId: int}
     */
    public static function getTickets(array $filters): array
    {
        $criteria = [];
        $view = (string) ($filters['view'] ?? 'incidents');
        $query = trim((string) ($filters['q'] ?? ''));
        $status = (string) ($filters['status'] ?? '');
        $severity = strtolower((string) ($filters['severity'] ?? ''));

        if (in_array($view, ['incidents', 'investigations'], true)) {
            $nameOption = self::optionId('name');
            $contentOption = self::optionId('content');
            $criteria[] = [
                'criteria' => [
                    [
                        'field'     => $nameOption,
                        'searchtype' => 'contains',
                        'value'     => 'Sentinel incident',
                    ],
                    [
                        'link'      => 'OR',
                        'field'     => $contentOption,
                        'searchtype' => 'contains',
                        'value'     => 'Microsoft Sentinel',
                    ],
                ],
            ];
        } elseif ($view === 'assigned') {
            $criteria[] = [
                'field'      => 5,
                'searchtype' => 'equals',
                'value'      => (string) Session::getLoginUserID(),
            ];
        } else {
            throw new \InvalidArgumentException('Unknown SOC ticket view.');
        }

        if ($query !== '') {
            $criteria[] = [
                'criteria' => [
                    [
                        'field'      => self::optionId('name'),
                        'searchtype' => 'contains',
                        'value'      => $query,
                    ],
                    [
                        'link'       => 'OR',
                        'field'      => self::optionId('content'),
                        'searchtype' => 'contains',
                        'value'      => $query,
                    ],
                ],
            ];
        }

        if (ctype_digit($status) && (int) $status >= Ticket::INCOMING && (int) $status <= Ticket::CLOSED) {
            $criteria[] = [
                'field'      => self::optionId('status'),
                'searchtype' => 'equals',
                'value'      => $status,
            ];
        }

        if (in_array($severity, ['critical', 'high', 'medium', 'low'], true)) {
            $criteria[] = [
                'field'      => self::optionId('content'),
                'searchtype' => 'contains',
                'value'      => ucfirst($severity),
            ];
        }

        if ($view === 'investigations') {
            $criteria[] = [
                'criteria' => [
                    [
                        'field'      => self::optionId('status'),
                        'searchtype' => 'equals',
                        'value'      => (string) Ticket::INCOMING,
                    ],
                    [
                        'link'       => 'OR',
                        'field'      => self::optionId('status'),
                        'searchtype' => 'equals',
                        'value'      => (string) Ticket::ASSIGNED,
                    ],
                    [
                        'link'       => 'OR',
                        'field'      => self::optionId('status'),
                        'searchtype' => 'equals',
                        'value'      => (string) Ticket::PLANNED,
                    ],
                    [
                        'link'       => 'OR',
                        'field'      => self::optionId('status'),
                        'searchtype' => 'equals',
                        'value'      => (string) Ticket::WAITING,
                    ],
                ],
            ];
        }

        $start = max(0, min(10000, (int) ($filters['start'] ?? 0)));
        $limit = max(1, min(100, (int) ($filters['limit'] ?? 25)));
        $result = self::search($criteria, $start, $limit);

        return [
            'tickets'       => $result['tickets'],
            'total'         => $result['total'],
            'start'         => $start,
            'limit'         => $limit,
            'currentUserId' => (int) Session::getLoginUserID(),
        ];
    }

    /**
     * Return one ticket and GLPI-filtered timeline entries.
     */
    public static function getTicket(int $id): array
    {
        $ticket = new Ticket();
        if ($id < 1 || !$ticket->getFromDB($id) || !$ticket->canViewItem()) {
            throw new \RuntimeException('Ticket not found or not visible.');
        }

        $formatted = self::formatTicketFields($ticket->fields, []);
        $formatted['canUpdate'] = $ticket->canUpdateItem();
        $formatted['requester'] = self::actorNames($ticket, CommonITILActor::REQUESTER);
        $formatted['assignees'] = self::actorNames($ticket, CommonITILActor::ASSIGN);
        $formatted['affectedAssets'] = self::affectedAssets($id);
        $formatted['description'] = self::plainText((string) ($ticket->fields['content'] ?? ''));
        $formatted['references'] = self::extractReferences((string) ($ticket->fields['content'] ?? ''));
        $formatted['solution'] = self::plainText((string) ($ticket->fields['solution'] ?? ''));
        $formatted['timeline'] = self::timeline($ticket);

        return $formatted;
    }

    /**
     * Run GLPI's native search engine so entity and ticket ACL rules are applied.
     *
     * @return array{tickets: array, total: int}
     */
    private static function search(array $criteria, int $start, int $limit): array
    {
        $dateOption = self::optionId('date');
        $forced = array_values(self::optionIds());
        $forced[] = 4; // requester
        $forced[] = 5; // assigned users
        $forced[] = 8; // assigned groups
        $forced = array_values(array_unique($forced));

        $data = Search::getDatas(
            Ticket::class,
            [
                'criteria'        => $criteria,
                'sort'            => [$dateOption],
                'order'           => ['DESC'],
                'start'           => $start,
                'list_limit'      => $limit,
                'is_deleted'      => 0,
                'export_all'      => 0,
                'display_type'    => Search::HTML_OUTPUT,
                'showmassiveactions' => false,
                'show_pager'      => false,
                'show_footer'     => false,
            ],
            $forced
        );

        $rows = $data['data']['rows'] ?? [];
        $tickets = [];
        foreach ($rows as $row) {
            if (!is_array($row) || empty($row['id'])) {
                continue;
            }
            $raw = [];
            $raw['id'] = (int) $row['id'];
            foreach (self::optionIds() as $field => $optionId) {
                $raw[$field] = self::fieldValue($row, (string) $optionId, $field);
            }
            $tickets[] = self::formatTicketFields($raw, $row);
        }

        return [
            'tickets' => $tickets,
            'total'   => (int) ($data['data']['totalcount'] ?? count($tickets)),
        ];
    }

    private static function formatTicketFields(array $fields, array $row): array
    {
        $id = (int) ($fields['id'] ?? 0);
        $name = trim((string) ($fields['name'] ?? ''));
        $content = (string) ($fields['content'] ?? '');
        $plain = self::plainText($content);
        $status = (int) ($fields['status'] ?? 0);
        $priority = (int) ($fields['priority'] ?? 0);
        $date = (string) ($fields['date'] ?? '');
        $dateMod = (string) ($fields['date_mod'] ?? $date);
        $severity = self::extractSeverity($plain);
        $haystack = $name . "\n" . $plain;
        $isSoc = preg_match('/Sentinel incident\s+\d+/i', $haystack) === 1
            || stripos($haystack, 'Microsoft Sentinel') !== false;
        $incidentNumber = null;
        if (preg_match('/Sentinel incident\s+(\d+)/i', $haystack, $matches) === 1) {
            $incidentNumber = $matches[1];
        }
        $incidentGuid = null;
        if (preg_match('/\[([0-9a-f]{8}-[0-9a-f-]{27,})\]/i', $name, $matches) === 1) {
            $incidentGuid = $matches[1];
        }

        $assignees = self::usersFromSearchRow($row, 'User_5');
        $sourceIp = self::extractLabel($plain, [
            'Observed source',
            'Source IP',
            'Observed source address as recorded by the application',
            'Source address as recorded by the application',
            'Source address',
        ]);
        $asset = self::extractLabel($plain, ['Affected asset', 'Asset']);
        $ruleName = self::extractLabel($plain, ['Detection rule']);
        if (preg_match('/Microsoft Sentinel detected\s+(.+?)(?:\.|$)/i', $plain, $matches) === 1) {
            $ruleName ??= trim($matches[1]);
        }
        $mitre = null;
        if (preg_match('/\bT\d{4}(?:\.\d{3})?\b/i', $plain, $matches) === 1) {
            $mitre = strtoupper($matches[0]);
        }
        $entities = self::extractEntities($plain);

        return [
            'id'                => $id,
            'title'             => $name !== '' ? $name : 'Untitled ticket',
            'status'            => $status,
            'statusLabel'       => self::statusLabel($status),
            'priority'          => $priority,
            'priorityLabel'     => CommonITILObject::getPriorityName($priority),
            'severity'           => $severity,
            'severityLabel'      => $severity !== null ? ucfirst($severity) : 'Not provided',
            'date'               => $date,
            'dateMod'            => $dateMod,
            'isSocCase'          => $isSoc,
            'incidentNumber'     => $incidentNumber,
            'incidentGuid'       => $incidentGuid,
            'detectionRule'      => $ruleName ?? '',
            'sourceIp'           => $sourceIp,
            'affectedAsset'      => $asset,
            'entities'           => $entities,
            'mitre'              => $mitre,
            'assignees'          => $assignees,
            'isAssignedToMe'     => in_array(
                (int) Session::getLoginUserID(),
                array_column($assignees, 'id'),
                true
            ),
            'summary'            => self::summaryText($plain),
        ];
    }

    private static function optionIds(): array
    {
        if (self::$optionIds !== null) {
            return self::$optionIds;
        }

        $wanted = self::TICKET_FIELDS;
        $found = [];
        foreach (Search::getOptions(Ticket::class) as $id => $option) {
            if (
                ($option['table'] ?? null) === Ticket::getTable()
                && isset($option['field'])
                && in_array($option['field'], $wanted, true)
            ) {
                $found[$option['field']] = (int) $id;
            }
        }

        foreach (['name', 'date', 'content', 'status', 'priority'] as $required) {
            if (!isset($found[$required])) {
                throw new \RuntimeException('Required GLPI ticket search field is unavailable.');
            }
        }

        self::$optionIds = $found;
        return $found;
    }

    private static function optionId(string $field): int
    {
        $ids = self::optionIds();
        if (!isset($ids[$field])) {
            throw new \RuntimeException('GLPI ticket search field is unavailable.');
        }
        return $ids[$field];
    }

    private static function fieldValue(array $row, string $key, string $field): mixed
    {
        $values = $row[$key] ?? null;
        if (is_array($values)) {
            if (isset($values[0]) && is_array($values[0])) {
                return $values[0][$field] ?? null;
            }
            if (isset($values[$field])) {
                return $values[$field];
            }
        }
        return $row[$field] ?? null;
    }

    private static function usersFromSearchRow(array $row, string $key): array
    {
        $records = $row[$key] ?? [];
        if (!is_array($records)) {
            return [];
        }
        $result = [];
        foreach ($records as $record) {
            if (!is_array($record) || empty($record['id'])) {
                continue;
            }
            $name = trim((string) ($record['displayname'] ?? $record['name'] ?? ''));
            if ($name === '') {
                $name = trim(
                    (string) ($record['firstname'] ?? '') . ' '
                    . (string) ($record['realname'] ?? '')
                );
            }
            $result[] = [
                'id'   => (int) $record['id'],
                'name' => $name !== '' ? $name : 'GLPI user',
            ];
        }
        return $result;
    }

    private static function actorNames(Ticket $ticket, int $type): array
    {
        $names = [];
        $actors = $ticket->getUsers($type);
        foreach ($actors as $actor) {
            $userId = (int) ($actor['users_id'] ?? 0);
            if ($userId < 1) {
                continue;
            }
            $user = new User();
            if ($user->getFromDB($userId)) {
                $names[] = [
                    'id'   => $userId,
                    'name' => (string) $user->getFriendlyName(),
                ];
            }
        }
        return $names;
    }

    private static function affectedAssets(int $ticketId): array
    {
        global $DB;

        $items = [];
        $iterator = $DB->request([
            'FROM'  => 'glpi_items_tickets',
            'WHERE' => [
                'tickets_id' => $ticketId,
            ],
            'LIMIT' => 20,
        ]);

        foreach ($iterator as $link) {
            $itemtype = (string) ($link['itemtype'] ?? '');
            $itemsId = (int) ($link['items_id'] ?? 0);
            if ($itemsId < 1 || !is_a($itemtype, \CommonDBTM::class, true)) {
                continue;
            }
            $asset = new $itemtype();
            if ($asset->getFromDB($itemsId) && $asset->canViewItem()) {
                $items[] = [
                    'type' => (string) $asset->getTypeName(),
                    'name' => (string) $asset->getFriendlyName(),
                ];
            }
        }

        return $items;
    }

    private static function timeline(Ticket $ticket): array
    {
        $events = [];
        foreach ($ticket->getTimelineItems([
            'with_documents'    => true,
            'with_logs'         => true,
            'with_validations'  => true,
            'sort_by_date_desc' => true,
            'check_view_rights' => true,
            'hide_private_items' => false,
        ]) as $entry) {
            $item = $entry['item'] ?? [];
            if (!is_array($item)) {
                continue;
            }
            $type = (string) ($entry['type'] ?? '');
            $label = 'Case activity';
            if (stripos($type, 'Followup') !== false) {
                $label = 'Investigation note';
            } elseif (stripos($type, 'Task') !== false) {
                $label = 'Analyst action';
            } elseif (stripos($type, 'Document') !== false) {
                $label = 'Evidence attached';
            } elseif (stripos($type, 'Validation') !== false) {
                $label = 'Approval activity';
            }

            $authorId = (int) ($item['users_id'] ?? 0);
            $author = '';
            if ($authorId > 0) {
                $user = new User();
                if ($user->getFromDB($authorId)) {
                    $author = (string) $user->getFriendlyName();
                }
            }
            $content = self::plainText((string) ($item['content'] ?? ''));
            $events[] = [
                'id'      => (int) ($item['id'] ?? 0),
                'type'    => $label,
                'date'    => (string) ($item['date'] ?? $item['date_creation'] ?? ''),
                'author'  => $author !== '' ? $author : 'GLPI',
                'content' => $content !== '' ? $content : 'Ticket activity recorded.',
            ];
        }
        return array_slice($events, 0, 60);
    }

    private static function emptyTrend(): array
    {
        $trend = [];
        $date = new \DateTimeImmutable('today', new \DateTimeZone('UTC'));
        for ($offset = 13; $offset >= 0; $offset--) {
            $key = $date->modify('-' . $offset . ' days')->format('Y-m-d');
            $trend[$key] = 0;
        }
        return $trend;
    }

    private static function statusLabel(int $status): string
    {
        return match ($status) {
            Ticket::INCOMING => 'New',
            Ticket::ASSIGNED => 'Assigned',
            Ticket::PLANNED  => 'Planned',
            Ticket::WAITING  => 'Waiting',
            Ticket::SOLVED   => 'Resolved',
            Ticket::CLOSED   => 'Closed',
            default          => 'Unknown',
        };
    }

    private static function extractSeverity(string $content): ?string
    {
        if (preg_match('/\bSeverity\s*:\s*(critical|high|medium|low)\b/i', $content, $matches) === 1) {
            return strtolower($matches[1]);
        }
        if (preg_match('/\bseverity\s+(critical|high|medium|low)\b/i', $content, $matches) === 1) {
            return strtolower($matches[1]);
        }
        return null;
    }

    private static function extractLabel(string $content, array $labels): ?string
    {
        foreach ($labels as $label) {
            $pattern = '/\b' . preg_quote($label, '/') . '\s*:\s*([^\r\n]+)/i';
            if (preg_match($pattern, $content, $matches) !== 1) {
                continue;
            }
            $value = trim($matches[1], " \t\n\r\0\x0B,;");
            $value = preg_split('/\s+(?:Correlation ID|Severity|Detection window|Affected asset)\s*:/i', $value)[0];
            if ($value !== '') {
                return mb_substr($value, 0, 160);
            }
        }
        return null;
    }

    private static function extractEntities(string $content): array
    {
        $labels = [
            'Affected accounts?',
            'Target account hashes',
            'Target identifiers \\(anonymized hashes\\)',
        ];
        foreach ($labels as $label) {
            if (preg_match('/' . $label . '\s*:\s*([^\r\n]+)/i', $content, $matches) === 1) {
                $values = preg_split('/\s*[,;|]\s*/', trim($matches[1], " \t\n\r\0\x0B[]")) ?: [];
                $values = array_filter(array_map(
                    static fn (string $value): string => trim($value, " \t\n\r\0\x0B\"'[]"),
                    $values
                ));
                return array_slice(array_map(
                    static fn (string $value): string => mb_substr($value, 0, 120),
                    $values
                ), 0, 12);
            }
        }
        return [];
    }

    private static function extractReferences(string $html): array
    {
        if (preg_match_all('~<a\b[^>]*href="([^"]+)"[^>]*>(.*?)</a>~is', $html, $matches, PREG_SET_ORDER) === false) {
            return [];
        }

        $references = [];
        foreach ($matches as $match) {
            $href = html_entity_decode($match[1], ENT_QUOTES | ENT_HTML5, 'UTF-8');
            $parts = parse_url($href);
            if (
                !is_array($parts)
                || strtolower((string) ($parts['scheme'] ?? '')) !== 'https'
                || strtolower((string) ($parts['host'] ?? '')) !== 'portal.azure.com'
            ) {
                continue;
            }
            $label = self::plainText($match[2]);
            if ($label === '') {
                $label = 'Open Azure reference';
            }
            $references[] = [
                'href'  => $href,
                'label' => mb_substr($label, 0, 100),
            ];
            if (count($references) >= 10) {
                break;
            }
        }
        return $references;
    }

    private static function summaryText(string $plain): string
    {
        $summary = trim(preg_split('/\n\s*(?:What to find out|Investigation Objective|How to investigate)\b/i', $plain)[0]);
        return mb_substr($summary !== '' ? $summary : $plain, 0, 1200);
    }

    private static function plainText(string $html): string
    {
        $withSpacing = preg_replace('#</(?:p|li|h[1-6]|div|tr|br)>#i', "\n", $html);
        $plain = html_entity_decode(strip_tags($withSpacing ?? $html), ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $plain = preg_replace('/[ \t]+/', ' ', $plain);
        $plain = preg_replace('/\n{3,}/', "\n\n", $plain);
        return trim($plain ?? '');
    }
}
