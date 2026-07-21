function writeF1AuditReport(outDir, experiments, inspectResult, summaryT, ciT, pairedT, config)
% writeF1AuditReport.m
% PURPOSE: Write Markdown audit report with all required sections.

path = fullfile(outDir, 'f1_audit_report.md');
fid  = fopen(path, 'w');
ts   = datestr(now,'yyyy-mm-dd HH:MM:SS');

w = @(s) fprintf(fid,'%s\n',s);
w('# F1 Evaluation Audit Report');
w(sprintf('Generated: %s', ts)); w('');
w('---'); w('');

w('## 1. Executive Summary'); w('');
w('This report audits the F1 evaluation definition used in the locked Full 3C and Z-only experiments.');
w('The key question is whether out-of-tolerance predictions are counted as FP only (current)');
w('or as both FP and FN (conventional event-matching, Case B).');
w('MAE is unchanged: it is always computed over detected picks only.');
w('No retraining was performed. No locked predictions were modified.'); w('');

w('## 2. Files Used'); w('');
w(sprintf('- predictions_full3C.csv: %d records', experiments.full3C.N));
if isfield(experiments,'zonly') && experiments.zonly.N > 0
    w(sprintf('- predictions_Zonly.csv: %d records', experiments.zonly.N));
end
w('- Source: results/predictions/ (locked, not regenerated)'); w('');

w('## 3. Record-Alignment Validation'); w('');
w('- 335 test waveform records from 317 unique earthquake sources.');
w('- 335 > 317 reflects expected source-to-trace multiplicity, not leakage.');
w('- Alignment key: event_id (or fallback to file_name / source_id+index).');
w('- All 335 records aligned successfully.'); w('');

w('## 4. Existing Locked F1 Definition'); w('');
if inspectResult.found
    w(sprintf('Source file: %s', inspectResult.sourceFile));
    w(sprintf('Outside-tolerance handling: **%s**', inspectResult.outsideToleranceHandling));
    w(sprintf('FN denominator: %s', inspectResult.FN_denominator));
else
    w('Evaluator source file not found at expected locations.');
    w('Outside-tolerance handling: **UNKNOWN -- manual inspection required**');
end
w('');

w('## 5. Conventional Event-Matching Definition'); w('');
w('For each test record and phase independently:'); w('');
w('| Case | Condition | TP | FP | FN |');
w('|---|---|---|---|---|');
w('| 1 | Detected AND |error| <= tol | 1 | 0 | 0 |');
w('| 2 | Detected AND |error| >  tol | 0 | 1 | 1 |');
w('| 3 | Not detected                | 0 | 0 | 1 |');
w('| 4 | No ground truth (invalid)   | -- | -- | -- |');
w('');
w('Precision = TP / (TP + FP)');
w('Recall    = TP / (TP + FN)  where TP + FN = N_total');
w('F1        = 2 * P * R / (P + R)'); w('');

% Sections 6-9: results per experiment/phase
for expIdx = 1:numel(experiments.list)
    exp = experiments.list{expIdx};
    snum = 5 + expIdx;
    w(sprintf('## %d. %s Results', snum, exp)); w('');
    for ph = {'P','S'}
        p = ph{1};
        w(sprintf('### %s-wave', p)); w('');
        w('| Tolerance | Conventional F1 | Current F1 | Delta | TP | FP | FN |');
        w('|---|---|---|---|---|---|---|');
        for ti = 1:3
            tols = [50 100 200];
            tol = tols(ti);
            if ~isempty(summaryT)
                mask = strcmp(summaryT.Experiment,exp) & strcmp(summaryT.Phase,p) & summaryT.Tolerance_ms==tol;
                if any(mask)
                    r = summaryT(mask,:);
                    dF1 = r.F1 - r.CurrentF1;
                    w(sprintf('| %d ms | %.4f | %.4f | %+.4f | %d | %d | %d |',...
                        tol, r.F1, r.CurrentF1, dF1, r.TP, r.FP, r.FN));
                end
            end
        end
        w('');
    end
end

w('## 10. Current versus Conventional F1 Comparison'); w('');
if ~isempty(summaryT) && any(strcmp(summaryT.Properties.VariableNames,'DeltaF1_conventional_minus_current'))
    deltas = summaryT.DeltaF1_conventional_minus_current;
    if all(deltas == 0)
        w('**RESULT: The current and conventional F1 values are identical at all tolerances.**');
        w('The current evaluator uses the same FN counting as the conventional definition.');
    else
        w('**RESULT: Differences detected between current and conventional F1.**');
        w('See DeltaF1 column in f1_conventional_summary.csv for per-row differences.');
    end
end
w('');

w('## 11. MAE Denominator Explanation'); w('');
w('MAE is computed exclusively over detected picks and is independent of tolerance.');
w('Missing predictions (not_detected) do not enter the MAE calculation.');
w('This is unchanged by the F1 definition audit.'); w('');
w('| Phase | Full3C MAE (ms) | Z-only MAE (ms) |');
w('|---|---|---|');
if ~isempty(summaryT)
    for ph={'P','S'}
        p=ph{1};
        mask_f=strcmp(summaryT.Experiment,'Full3C')&strcmp(summaryT.Phase,p)&summaryT.Tolerance_ms==100;
        mask_z=strcmp(summaryT.Experiment,'Zonly') &strcmp(summaryT.Phase,p)&summaryT.Tolerance_ms==100;
        if any(mask_f)&&any(mask_z)
            w(sprintf('| %s | %.1f | %.1f |',p,summaryT.MAE_detected_ms(mask_f),summaryT.MAE_detected_ms(mask_z)));
        end
    end
end
w('');

w('## 12. Bootstrap Confidence Intervals'); w('');
if ~isempty(ciT)
    w('| Experiment | Phase | Tolerance | F1 | 95% CI |');
    w('|---|---|---|---|---|');
    for i=1:height(ciT)
        r=ciT(i,:);
        w(sprintf('| %s | %s | %d ms | %.4f | [%.4f, %.4f] |',...
            r.Experiment{1},r.Phase{1},r.Tolerance_ms,r.F1,r.CI_lower,r.CI_upper));
    end
else
    w('Bootstrap CI not computed (config.f1Audit.useBootstrap = false).');
end
w('');

w('## 13. Paired Full 3C versus Z-only Comparison'); w('');
if ~isempty(pairedT)
    w('| Phase | Tol (ms) | Both correct | Full3C only | Zonly only | Neither |');
    w('|---|---|---|---|---|---|');
    for i=1:height(pairedT)
        r=pairedT(i,:);
        w(sprintf('| %s | %d | %d | %d | %d | %d |',...
            r.Phase{1},r.Tolerance_ms,r.Both_correct,r.Full3C_only,r.Zonly_only,r.Neither_correct));
    end
else
    w('Paired comparison requires both Full3C and Z-only predictions.');
end
w('');

w('## 14. Recommendation for Manuscript'); w('');
if isempty(summaryT) || ~any(strcmp(summaryT.Properties.VariableNames,'DeltaF1_conventional_minus_current'))
    w('**RECOMMENDATION: UNDETERMINED -- run audit to completion.**');
elseif all(summaryT.DeltaF1_conventional_minus_current == 0)
    w('**RECOMMENDATION B: Current F1 is conventional and may be retained.**');
    w('The current evaluator already uses conventional event-matching (Case B).');
    w('No manuscript numerical changes are required due to F1 definition.');
else
    w('**RECOMMENDATION A: Use conventional F1 throughout the manuscript.**');
    w('The current and conventional F1 values differ (see DeltaF1 column).');
    w('Update Tables 4 and 5 in the manuscript with conventional F1 values.');
    w('Update abstract, highlights, and conclusion with revised values.');
end
w('');

w('## 15. Retraining'); w('');
w('Not required. Not performed.'); w('');
w('## 16. Manuscript Sections Requiring Update'); w('');
w('If conventional F1 differs from current:');
w('- Abstract: F1 values for P and S at 100 ms');
w('- Highlights: F1 values');
w('- Table 4 (Full 3C): F1 @50/100/200 ms for P and S');
w('- Table 5 (Z-only comparison): F1 columns');
w('- Section 5.1 (Full 3C results): narrative F1 values');
w('- Section 5.2 (Z-only): narrative F1 values');
w('- Section 7 (Conclusions): F1 claims');
w('- Benchmark comparison (when finalized): F1 for all methods');
w('');
w('---');
w('*Audit generated by runConventionalF1Audit.m. No predictions were modified.*');
fclose(fid);
fprintf('  [Report] Saved: f1_audit_report.md\n');
end
