function smoke_public_v2
% Exercise the portable interface on fixed existing records; no model fitting.
root='C:\Users\catur\.codex\visualizations\2026\09\11\01a08fc7-0cf1-7772-a384-020417c19593\sync_repo\source_verified_v2';addpath(root);
wave='C:\Drive E\ICNN_MetaPicker_Curated_STEAD_MATLAB\data\csv_stead_filtered';out='C:\Users\catur\.codex\visualizations\2026\09\11\01a08fc7-0cf1-7772-a384-020417c19593\cg_final_20260918\portable_smoke';
for mode=["Full3C","Zonly"]
 for base=42:44
  replay_v2(wave,out,'test',mode,base,3,'gpu');
  replay_v2(wave,out,'oof',mode,base,3,'gpu');
 end
 replay_v2(wave,out,'phasenet',mode,42,3,'gpu');
end
fprintf('PASS portable v2: all 14 groups, three original records per group, no training.\n');
end
