% =========================================================================
% setPublicationStyle.m
% =========================================================================
% PURPOSE:
%   Mengatur default style MATLAB untuk seluruh figure publikasi C&G.
%   Dipanggil SEKALI di awal run_generate_all_figures.m.
%   Semua figure yang dibuat setelah ini otomatis menggunakan style ini.
% =========================================================================

function setPublicationStyle()

set(groot, 'defaultFigureColor',           'white');
set(groot, 'defaultAxesFontName',          'Arial');
set(groot, 'defaultAxesFontSize',          14);
set(groot, 'defaultAxesTickDir',           'out');
set(groot, 'defaultAxesBox',               'off');
set(groot, 'defaultAxesLineWidth',         0.8);
set(groot, 'defaultAxesGridAlpha',         0.2);
set(groot, 'defaultAxesXGrid',             'on');
set(groot, 'defaultAxesYGrid',             'on');
set(groot, 'defaultAxesMinorGridLineStyle','none');
set(groot, 'defaultLineLineWidth',         2.0);
set(groot, 'defaultLineMarkerSize',        8);
set(groot, 'defaultTextFontName',          'Arial');
set(groot, 'defaultLegendFontSize',        13);
set(groot, 'defaultLegendBox',             'off');

fprintf('  [Style] Publication style applied (Arial, C&G layout).\n');
end
