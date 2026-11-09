<?php

namespace GlpiPlugin\Socops;

use CommonDBTM;
use Ticket;

final class Menu extends CommonDBTM
{
    public static function getTypeName($nb = 0): string
    {
        return __('SOC Analyst Platform', 'socops');
    }

    public static function getMenuName($nb = 0): string
    {
        return self::getTypeName($nb);
    }

    public static function getMenuContent(): array
    {
        if (!Ticket::canView()) {
            return [];
        }

        $workspace = '/plugins/socops/dashboard';

        return [
            'title' => self::getTypeName(),
            'page'  => $workspace,
            'icon'  => 'ti ti-shield-lock',
            'links' => [
                'dashboard' => $workspace,
            ],
        ];
    }
}
