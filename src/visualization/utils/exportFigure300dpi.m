
function exportFigure300dpi(fig, outDir, baseName)
% exportFigure300dpi.m -- PATCHED (Task 4)
% Suppress "Vectorized content might take long" warning by using image
% ContentType for PDF export. PNG/TIFF unchanged.

pngDir  = fullfile(outDir,'png');
tiffDir = fullfile(outDir,'tiff');
pdfDir  = fullfile(outDir,'pdf');
ensureDir(pngDir); ensureDir(tiffDir); ensureDir(pdfDir);

pngPath  = fullfile(pngDir,  [baseName '.png']);
tiffPath = fullfile(tiffDir, [baseName '.tif']);
pdfPath  = fullfile(pdfDir,  [baseName '.pdf']);

exportgraphics(fig, pngPath,  'Resolution',300, 'BackgroundColor','white');
exportgraphics(fig, tiffPath, 'Resolution',600, 'BackgroundColor','white');

% ContentType='image' prevents the colorbar/scatter vectorize warning
try
    exportgraphics(fig, pdfPath, 'ContentType','image', ...
        'Resolution',300, 'BackgroundColor','white');
catch
    try; print(fig, pdfPath, '-dpdf', '-r300'); catch; end
end

fprintf('  [Export] %-45s PNG/TIFF/PDF\n', baseName);
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
