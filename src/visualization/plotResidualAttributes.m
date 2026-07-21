% =========================================================================
% plotResidualAttributes.m     Fig 08
% =========================================================================
% PURPOSE:
%   Residual vs geophysical attributes: distance, magnitude, SNR, S-P time.
%   Dengan LOWESS smoothing dan Pearson/Spearman correlation.
% =========================================================================

function caption = plotResidualAttributes(predTable, data, outDir)

C = vizColors();

% Gabungkan atribut dari data jika predTable belum punya
predTable = enrichFromData(predTable, data);

% Attribute definitions
attrs = {
    'source_distance_km', 'Source Distance (km)', C.blue;
    'source_magnitude',   'Source Magnitude (M_L)', C.orange;
    'SNR',                'SNR (dB)',             C.green;
    'sp_time_sec',        'S-P Time (s)',          C.purple
};

comps = {'P','S'};
fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 30 16]);
sgtitle('Picking Residuals vs. Geophysical Attributes','FontSize',16,'FontName','Arial','FontWeight','bold');

nAttr = size(attrs,1);
panelIdx = 0;
for ci = 1:2
    comp  = comps{ci};
    col   = ternary(ci==1, C.Pwave, C.Swave);
    errMs = safeNum(predTable, ternary(ci==1,'p_error_ms','s_error_ms'));

    for ai = 1:nAttr
        panelIdx = panelIdx + 1;
        ax = subplot(2, nAttr, panelIdx); %#ok
        hold on;

        attrCol = attrs{ai,1};
        attrLab = attrs{ai,2};
        attrClr = attrs{ai,3};
        attrVal = safeNum(predTable, attrCol);

        valid = ~isnan(errMs) & ~isnan(attrVal);
        ev = errMs(valid); av = attrVal(valid);

        if numel(av) < 5
            text(0.5,0.5,'N/A','Units','normalized','HorizontalAlignment','center');
            title(sprintf('(%s vs %s)', comp, attrCol),'FontSize',12);
            continue;
        end

        % Scatter
        scatter(av, ev, 15, col, 'filled','MarkerFaceAlpha',0.4);

        % Tolerance reference
        yline(0,  'k-','LineWidth',1.2);
        yline(100, ':','Color',[0.5 0.5 0.5],'LineWidth',0.8);
        yline(-100,':','Color',[0.5 0.5 0.5],'LineWidth',0.8);

        % LOWESS smoothing
        try
            av_s = sort(av); ev_s = ev(av==av_s | true);  % reorder
            [avS, sIdx] = sort(av); evS = ev(sIdx);
            smoothed = smooth(avS, evS, 0.4, 'lowess');
            plot(avS, smoothed, '-', 'Color', col*0.6, 'LineWidth', 2.5, ...
                'DisplayName','LOWESS');
        catch; end

        % Pearson + Spearman
        pr = corr(av, ev, 'type','Pearson');
        sp = corr(av, ev, 'type','Spearman');
        statsStr = sprintf('r=%.3f\n\\rho=%.3f\nN=%d', pr, sp, numel(av));
        text(0.97,0.97,statsStr,'Units','normalized','HorizontalAlignment','right', ...
            'VerticalAlignment','top','FontSize',9,'FontName','Arial', ...
            'BackgroundColor','white','EdgeColor',[0.7 0.7 0.7],'Margin',3);

        xlabel(attrLab,'FontSize',12,'FontName','Arial');
        if ai==1; ylabel(sprintf('%s Error (ms)',comp),'FontSize',13,'FontName','Arial'); end
        panelLetter = char('a' + panelIdx - 1);
        title(sprintf('(%s) %s vs. %s', panelLetter, comp, attrLab), ...
            'FontSize',12,'FontName','Arial','FontWeight','bold');
        set(ax,'FontSize',11,'FontName','Arial','Box','off','TickDir','out');
        grid on; ax.GridAlpha=0.2;
        ylim([-1500 1500]);
    end
end

caption = ['Fig. 8. Picking residuals as a function of geophysical attributes. ' ...
    'Columns show residuals versus (a,e) source distance, (b,f) source magnitude, ' ...
    '(c,g) signal-to-noise ratio, and (d,h) S-P time, for P-wave (top row) and ' ...
    'S-wave (bottom row). LOWESS smoothing curves are overlaid (thick lines). ' ...
    'Pearson (r) and Spearman (ρ) correlation coefficients are annotated. ' ...
    'Horizontal dotted lines indicate ±100 ms tolerance.'];

ensureDir(outDir);
exportFigure300dpi(fig, outDir, 'Fig08_ResidualAttributes');
close(fig);
end

function predTable = enrichFromData(predTable, data)
if isempty(data); return; end
needCols = {'source_distance_km','source_magnitude','SNR','sp_time_sec'};
hasCol = @(t,c) any(strcmpi(t.Properties.VariableNames,c));
eids = safeStr(predTable,'event_id');
dataEids = {};
try; for i=1:numel(data); dataEids{i}=data(i).event_id; end; catch; end

for nc = needCols
    col = nc{1};
    if hasCol(predTable,col); continue; end
    predTable.(col) = nan(height(predTable),1);
    for ri = 1:height(predTable)
        idx = find(strcmp(dataEids,eids{ri}),1);
        if ~isempty(idx) && isfield(data,col) && ~isnan(data(idx).(col))
            predTable.(col)(ri) = data(idx).(col);
        end
    end
end
end

function v=safeNum(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=nan(height(t),1);return;end
v=double(t.(t.Properties.VariableNames{find(idx,1)}));
end
function v=safeStr(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=repmat({''},height(t),1);return;end
v=cellstr(string(t.(t.Properties.VariableNames{find(idx,1)})));
end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
