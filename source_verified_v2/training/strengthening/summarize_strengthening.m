function summarize_strengthening(resultsRoot,frozenRoot,sourceRoot)
% Retain meta-within-base structure. CIs are conditional on a fixed fit/split.
if nargin<2;frozenRoot='D:\ICNN_source_verified_results\v2\submission40';end
p=fileparts(mfilename('fullpath'));addpath(fullfile(p,'clean'));
if nargin<3;sourceRoot='D:\STEAD_identity_recovery\prepared_source_v2';end
verifiedProtocol(sourceRoot);expectedProtocol=sha256File(fullfile(sourceRoot,'protocol.json'));
runRoots=string(frozenRoot);
for b=43:44;for mode=["Full3C","Zonly"];runRoots(end+1)=fullfile(resultsRoot,"base_"+b,mode);end;end
for mode=["Full3C","Zonly"];for b=42:44;runRoots(end+1)=fullfile(resultsRoot,'phasenet',mode,"seed_"+b);end;end
for r=runRoots
 manifestFile=fullfile(r,'manifest.mat');
 if isfile(manifestFile)
  receipt=load(manifestFile,'configuration');c=jsondecode(receipt.configuration);
  assert(isfield(c,'sourceProtocolHash') && string(c.sourceProtocolHash)==expectedProtocol,'ICNN:MixedProtocols','Cannot summarize legacy or different source splits.');
 elseif ~isempty(dir(fullfile(r,'**','*_accepted_metrics.csv')))
  error('ICNN:MixedProtocols','Evaluation files without a verified run manifest are prohibited.');
 end
end
if ~isfolder(resultsRoot);mkdir(resultsRoot);end
rows={};missing=strings(0,1);paths=strings(0,1);hashes=strings(0,1);
for b=42:44
 for mode=["Full3C","Zonly"]
  for s=42:44
   file=stackPath(b,mode,s,'accepted_metrics');
   append(file,mode,b,s,"Stack");
  end
 end
end
for mode=["Full3C","Zonly"]
 for s=42:44
  file=baselinePath(mode,s,'accepted_metrics');append(file,mode,s,NaN,"PhaseNetMatched");
 end
end
writetable(table(missing),fullfile(resultsRoot,'missing_evaluations.csv'));
writetable(table(paths,hashes),fullfile(resultsRoot,'summary_input_hashes.csv'));
if isempty(rows);warning('No completed evaluations yet.');return;end
runs=vertcat(rows{:});writetable(runs,fullfile(resultsRoot,'strengthening_metrics.csv'));
stack=runs(runs.Method=="Stack",:);
if ~isempty(stack)
 within=groupsummary(stack,{'Mode','BaseSeed','Phase','Tolerance_ms'},'mean',{'F1','MAE_ms','AcceptedCoverage'});
 writetable(within,fullfile(resultsRoot,'stack_meta_averages_within_base.csv'));
 % GroupCount must equal 3 before interpreting a mean as a complete meta average.
end
if ~isempty(missing);warning('Partial summary: %d evaluations missing.',numel(missing));return;end
for b=42:44
 for s=42:44
  a=readVerifiedPredictions(stackPath(b,"Full3C",s,'predictions'),sourceRoot);
  z=readVerifiedPredictions(stackPath(b,"Zonly",s,'predictions'),sourceRoot);
  writetable(pairedClusterCI(a,z,2000,42,true),fullfile(resultsRoot,"paired_modes_base"+b+"_meta"+s+".csv"));
  for mode=["Full3C","Zonly"]
   t=a;if mode=="Zonly";t=z;end
   baseline=readVerifiedPredictions(baselinePath(mode,b,'predictions'),sourceRoot);
   writetable(pairedClusterCI(t,baseline,2000,42,true),fullfile(resultsRoot,"stack_minus_phasenet_"+mode+"_base"+b+"_meta"+s+".csv"));
  end
 end
end
 function file=stackPath(b,mode,s,suffix)
  if b==42;folder=fullfile(frozenRoot,mode,'evaluation');
  else;folder=fullfile(resultsRoot,"base_"+b,mode,mode,'evaluation');end
  file=fullfile(folder,"full15ch_seed"+s+"_"+suffix+".csv");
 end
 function file=baselinePath(mode,s,suffix)
  file=fullfile(resultsRoot,'phasenet',mode,"seed_"+s,mode,'evaluation',"PhaseNetMatched_seed"+s+"_"+suffix+".csv");
 end
 function append(file,mode,b,s,method)
  if ~isfile(file);missing(end+1,1)=file;return;end
  t=readtable(file);t.Mode=repmat(mode,height(t),1);t.BaseSeed=repmat(b,height(t),1);
  t.MetaSeed=repmat(s,height(t),1);t.Method=repmat(method,height(t),1);rows{end+1}=t;
  paths(end+1,1)=file;hashes(end+1,1)=sha256File(file);
 end
end
