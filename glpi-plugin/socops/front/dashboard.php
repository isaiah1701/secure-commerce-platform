<?php

require_once dirname(__DIR__, 3) . '/inc/includes.php';

if (Session::getLoginUserID() < 1) {
    Html::redirect($CFG_GLPI['root_doc'] . '/index.php');
}
if (!Ticket::canView()) {
    http_response_code(403);
    Html::displayRightError();
    exit;
}

$manifestPath = dirname(__DIR__) . '/public/.vite/manifest.json';
if (!is_readable($manifestPath)) {
    http_response_code(503);
    echo 'The SOC workspace interface has not been built.';
    exit;
}
$manifest = json_decode((string) file_get_contents($manifestPath), true);
$entry = is_array($manifest) ? ($manifest['src/main.tsx'] ?? null) : null;
if (!is_array($entry) || empty($entry['file'])) {
    http_response_code(503);
    echo 'The SOC workspace interface is unavailable.';
    exit;
}

$assetPrefix = '/plugins/socops/';
$css = $entry['css'] ?? [];
$initialTitle = __('SOC Analyst Platform', 'socops');
$apiUrl = $assetPrefix . 'front/api.php';
$currentUser = (string) ($_SESSION['glpiname'] ?? '');

header('Content-Type: text/html; charset=UTF-8');
header('Cache-Control: no-store, private');
?>
<!doctype html>
<html lang="<?php echo htmlspecialchars((string) ($_SESSION['glpilanguage'] ?? 'en_GB'), ENT_QUOTES, 'UTF-8'); ?>" data-soc-theme="dark">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="dark light">
    <meta name="robots" content="noindex,nofollow">
    <title><?php echo htmlspecialchars($initialTitle, ENT_QUOTES, 'UTF-8'); ?></title>
    <?php foreach ($css as $style): ?>
      <link rel="stylesheet" href="<?php echo htmlspecialchars($assetPrefix . $style, ENT_QUOTES, 'UTF-8'); ?>">
    <?php endforeach; ?>
    <script>
      window.SOCOPS_CONFIG = Object.freeze({
        apiUrl: <?php echo json_encode($apiUrl, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT); ?>,
        currentUser: <?php echo json_encode($currentUser, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT); ?>
      });
    </script>
    <script type="module" src="<?php echo htmlspecialchars($assetPrefix . $entry['file'], ENT_QUOTES, 'UTF-8'); ?>"></script>
  </head>
  <body>
    <a class="soc-skip-link" href="#soc-main">Skip to main content</a>
    <div id="soc-root">
      <div class="soc-startup" role="status" aria-live="polite">Loading your SOC workspace…</div>
    </div>
  </body>
</html>
