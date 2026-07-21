% =========================================================================
% inspectFailureProbabilityCurves.m
% =========================================================================
% PURPOSE:
%   OPSIONAL     Menampilkan probability curves P/S/Noise bersama waveform
%   untuk kasus failure. Memerlukan model terlatih dan menjalankan inference
%   TANPA retraining.
%
%   This function requires saved trained models and runs INFERENCE ONLY.
%   It does NOT retrain any model.
%
% INPUTS:
%   selectedCases    - table dari failure_cases_selected_<exp>.csv
%   trainedModelPath - char, path ke model_ICNN_meta.mat
%   config           - struct framework
%
% NOTES:
%   Jika probability curves belum tersimpan:
%   1. Load base models dari base_models_final.mat
%   2. Load I-CNN dari model_ICNN_meta.mat
%   3. Run inference ONLY pada selected cases
%   4. Plot probability curves bersama waveform
%
%   Set config.useProbabilityCurveInspection = true untuk mengaktifkan.
% =========================================================================

function inspectFailureProbabilityCurves(selectedCases, trainedModelPath, config)

if ~isfield(config,'useProbabilityCurveInspection') || ...
        ~config.useProbabilityCurveInspection
    fprintf('[ProbCurveInspect] Disabled. Set config.useProbabilityCurveInspection = true.\n');
    return;
end

if ~isfile(trainedModelPath)
    warning('[ProbCurveInspect] Model not found: %s', trainedModelPath);
    return;
end

fprintf('[ProbCurveInspect] Loading trained model for inference-only probability curve generation...\n');
fprintf('  NOTE: This runs inference only. No model retraining is performed.\n');

% Load models
S1 = load(trainedModelPath);
flds = fieldnames(S1);
icnnModel = S1.(flds{1});

basePath = fullfile(fileparts(trainedModelPath), '..', 'trained_base_models', 'base_models_final.mat');
if ~isfile(basePath)
    warning('[ProbCurveInspect] base_models_final.mat not found.');
    return;
end
S2 = load(basePath);
flds2 = fieldnames(S2);
baseModels = S2.(flds2{1});

outDir = fullfile(config.outputDiagnosticsFolder, 'failure_cases', 'prob_curves');
ensureDir(outDir);

for i = 1:height(selectedCases)
    fname   = selectedCases.file_name{i};
    expName = selectedCases.experiment{i};
    csvPath = fullfile(config.csvWaveformFolder, fname);
    if ~isfile(csvPath); csvPath = [csvPath '.csv']; end
    if ~isfile(csvPath)
        fprintf('  [Skip] %s not found\n', fname); continue;
    end

    try
        wf  = readtable(csvPath, 'VariableNamingRule','preserve');
        rec = struct();
        rec.waveform      = [wf.E, wf.N, wf.Z];
        rec.sec           = wf.sec;
        rec.p_arrival_sec = selectedCases.p_true_sec(i);
        rec.s_arrival_sec = selectedCases.s_true_sec(i);

        % Inference only
        rec = applyPreprocessing(rec, config);
        mf  = buildMetaFeatureFromModels(rec, baseModels, config);
        pred = predictICNNMetaLearner(icnnModel, mf, config);

        % Plot
        figPath = fullfile(outDir, sprintf('probcurve_%s_%s_rank%02d.png', ...
            expName, selectedCases.component{i}, i));
        plotWaveformWithProb(wf, pred{1}, selectedCases(i,:), figPath, config);
        fprintf('  [ProbCurve] Saved: %s\n', figPath);
    catch ME
        fprintf('  [ProbCurve] Error for %s: %s\n', fname, ME.message);
    end
end
end

function plotWaveformWithProb(wf, pred, row, figPath, config)
sec = wf.sec;
fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 18 14]);

CP=[0.122 0.467 0.706]; CS=[0.839 0.153 0.157];
chNames = {'E','N','Z'};
for ch = 1:3
    ax = subplot(4,1,ch);
    if ismember(chNames{ch}, wf.Properties.VariableNames)
        plot(sec, double(wf.(chNames{ch})), 'Color',[0.3 0.3 0.3], 'LineWidth',0.6);
    end
    ylabel(chNames{ch},'FontSize',9,'FontName','Arial');
    set(ax,'FontSize',8,'FontName','Arial','Box','off','XTickLabel',{});
    grid on; ax.GridAlpha=0.15;
end

ax4 = subplot(4,1,4); hold on;
plot(sec, pred.P,     '-', 'Color',CP, 'LineWidth',2.0, 'DisplayName','P (I-CNN)');
plot(sec, pred.S,     '-', 'Color',CS, 'LineWidth',2.0, 'DisplayName','S (I-CNN)');
fill([sec;flipud(sec)],[pred.Noise;zeros(size(sec))],...
    [0.7 0.7 0.7],'EdgeColor','none','FaceAlpha',0.4,'DisplayName','Noise');
xlabel('Time (s)','FontSize',9,'FontName','Arial');
ylabel('Probability','FontSize',9,'FontName','Arial');
legend('Location','northeast','FontSize',8,'FontName','Arial','Box','off');
ylim([-0.05 1.15]);
set(ax4,'FontSize',8,'FontName','Arial','Box','off','TickDir','out');
grid on; ax4.GridAlpha=0.15;

exportgraphics(fig, figPath,'Resolution',300,'BackgroundColor','white');
close(fig);
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
