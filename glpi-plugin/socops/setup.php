<?php

use Glpi\Plugin\Hooks;
use GlpiPlugin\Socops\Menu;

define('PLUGIN_SOCOPS_VERSION', '1.0.0');

/**
 * Register the SOC workspace in GLPI's native plugin menu.
 */
function plugin_init_socops(): void
{
    global $PLUGIN_HOOKS;

    require_once __DIR__ . '/src/Menu.php';

    $PLUGIN_HOOKS[Hooks::MENU_TOADD]['socops'] = [
        'plugins' => Menu::class,
    ];
}

function plugin_version_socops(): array
{
    return [
        'name'         => 'SOC Analyst Platform',
        'version'      => PLUGIN_SOCOPS_VERSION,
        'author'       => 'Secure Commerce Platform',
        'license'      => 'GPL-3.0-or-later',
        'requirements' => [
            'glpi' => [
                'min' => '11.0.0',
            ],
        ],
    ];
}

function plugin_socops_check_prerequisites(): bool
{
    return version_compare(GLPI_VERSION, '11.0.0', '>=');
}

function plugin_socops_check_config($verbose = false): bool
{
    return true;
}

/**
 * This plugin adds no tables or columns; all case data stays in GLPI.
 */
function plugin_socops_install(): bool
{
    return true;
}

function plugin_socops_uninstall(): bool
{
    return true;
}
