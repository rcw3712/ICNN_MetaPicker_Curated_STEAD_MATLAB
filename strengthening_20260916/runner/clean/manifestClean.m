function signature = manifestClean(packageRoot,sourceRoot,runRoot,cfg)
% Full input hashes, not timestamps or record counts alone.
code=dir(fullfile(packageRoot,'**','*.m'));
files=string(fullfile({code.folder},{code.name}))';
files=[files;string(cfg.metadataPath)];
for n=["train","val","test"]
    files(end+1,1)=string(fullfile(sourceRoot,'results','splits',n+"_source_ids.csv"));
end
waves=dir(fullfile(sourceRoot,'data','csv_stead_filtered','*.csv'));
assert(numel(waves)==2234,'Expected exactly 2234 waveform files.');
files=sort([files;string(fullfile({waves.folder},{waves.name}))']);
hashes=strings(numel(files),1);
fprintf('Hashing %d code/data files for run provenance...\n',numel(files));
for i=1:numel(files);hashes(i)=sha256File(files(i));end
manifest=table(files,hashes);configuration=jsonencode(cfg);
existing=fullfile(runRoot,'manifest.mat');
if isfile(existing)
    old=load(existing);
    assert(isequal(old.manifest,manifest)&&strcmp(old.configuration,configuration), ...
        'ICNN:ManifestMismatch','Code, data or configuration changed. Use a new run directory.');
else
    save(existing,'manifest','configuration');writetable(manifest,fullfile(runRoot,'manifest.csv'));
end
signature=sha256File(existing);
end
