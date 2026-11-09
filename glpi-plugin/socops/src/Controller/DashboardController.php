<?php

namespace GlpiPlugin\Socops\Controller;

use Glpi\Controller\AbstractController;
use Session;
use Symfony\Component\HttpFoundation\RedirectResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Ticket;

final class DashboardController extends AbstractController
{
    #[Route('/dashboard', name: 'socops_dashboard', methods: ['GET'])]
    public function __invoke(): Response
    {
        global $CFG_GLPI;

        $rootDoc = rtrim((string) ($CFG_GLPI['root_doc'] ?? ''), '/');
        if (Session::getLoginUserID() < 1) {
            return new RedirectResponse($rootDoc . '/index.php');
        }
        if (!Ticket::canView()) {
            throw new \Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException();
        }

        $pluginRoot = dirname(__DIR__, 2);
        $manifestPath = $pluginRoot . '/public/.vite/manifest.json';
        if (!is_readable($manifestPath)) {
            return new Response(
                'The SOC workspace interface has not been built.',
                Response::HTTP_SERVICE_UNAVAILABLE
            );
        }

        $manifest = json_decode((string) file_get_contents($manifestPath), true);
        $entry = is_array($manifest) ? ($manifest['src/main.tsx'] ?? null) : null;
        if (!is_array($entry) || empty($entry['file'])) {
            return new Response(
                'The SOC workspace interface is unavailable.',
                Response::HTTP_SERVICE_UNAVAILABLE
            );
        }

        $assetPrefix = $rootDoc . '/plugins/socops/';
        $cssLinks = '';
        foreach (($entry['css'] ?? []) as $style) {
            $href = htmlspecialchars($assetPrefix . $style, ENT_QUOTES, 'UTF-8');
            $cssLinks .= '<link rel="stylesheet" href="' . $href . '">' . "\n";
        }

        $language = htmlspecialchars(
            (string) ($_SESSION['glpilanguage'] ?? 'en_GB'),
            ENT_QUOTES,
            'UTF-8'
        );
        $title = htmlspecialchars(__('SOC Analyst Platform', 'socops'), ENT_QUOTES, 'UTF-8');
        $script = htmlspecialchars($assetPrefix . $entry['file'], ENT_QUOTES, 'UTF-8');
        $apiUrl = htmlspecialchars($rootDoc . '/plugins/socops/api', ENT_QUOTES, 'UTF-8');
        $currentUser = htmlspecialchars(
            (string) ($_SESSION['glpiname'] ?? ''),
            ENT_QUOTES,
            'UTF-8'
        );

        $html = '<!doctype html>' . "\n"
            . '<html lang="' . $language . '" data-soc-theme="dark">' . "\n"
            . '  <head>' . "\n"
            . '    <meta charset="UTF-8">' . "\n"
            . '    <meta name="viewport" content="width=device-width, initial-scale=1">' . "\n"
            . '    <meta name="color-scheme" content="dark light">' . "\n"
            . '    <meta name="robots" content="noindex,nofollow">' . "\n"
            . '    <title>' . $title . '</title>' . "\n"
            . $cssLinks
            . '    <script type="module" src="' . $script . '"></script>' . "\n"
            . '  </head>' . "\n"
            . '  <body>' . "\n"
            . '    <a class="soc-skip-link" href="#soc-main">Skip to main content</a>' . "\n"
            . '    <div id="soc-root" data-api-url="' . $apiUrl
            . '" data-current-user="' . $currentUser . '">' . "\n"
            . '      <div class="soc-startup" role="status" aria-live="polite">'
            . 'Loading your SOC workspace…</div>' . "\n"
            . '    </div>' . "\n"
            . '  </body>' . "\n"
            . '</html>';

        return new Response($html, Response::HTTP_OK, [
            'Content-Type'           => 'text/html; charset=UTF-8',
            'Cache-Control'          => 'no-store, private',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}
