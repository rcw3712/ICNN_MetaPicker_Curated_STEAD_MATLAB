% =========================================================================
% vizColors.m     konsisten color palette untuk seluruh framework visualisasi
% =========================================================================
function C = vizColors()
C.blue   = [0.122 0.467 0.706];
C.orange = [1.000 0.498 0.055];
C.green  = [0.173 0.627 0.173];
C.red    = [0.839 0.153 0.157];
C.purple = [0.580 0.404 0.741];
C.gray   = [0.498 0.498 0.498];
C.teal   = [0.086 0.627 0.522];
C.amber  = [0.769 0.557 0.063];

% Pasangan warna Full3C vs Zonly
C.full3C = C.green;
C.zonly  = C.orange;

% Pasangan warna P vs S
C.Pwave  = C.blue;
C.Swave  = C.red;

% SNR class
C.snrLow  = C.red;
C.snrMed  = C.orange;
C.snrHigh = C.green;
end
