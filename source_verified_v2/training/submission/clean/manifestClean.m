function signature = manifestClean(packageRoot,sourceRoot,runRoot,cfg)
[p,~]=verifiedProtocol(sourceRoot);
assert(isfield(cfg,'sourceProtocolHash') && string(cfg.sourceProtocolHash)==sha256File(fullfile(sourceRoot,'protocol.json')));
code=dir(fullfile(packageRoot,'**','*.m'));files=string(fullfile({code.folder},{code.name}))';
files=[files;string(fullfile(sourceRoot,'protocol.json'))];
for k=1:numel(p.files);files(end+1,1)=string(fullfile(sourceRoot,p.files(k).relative_path));end
waves=readtable(fullfile(sourceRoot,'waveform_hashes.csv'),'TextType','string');
assert(height(waves)==p.records && numel(dir(fullfile(cfg.csvFolder,'*.csv')))==p.records);
for i=1:height(waves)
 file=fullfile(cfg.csvFolder,waves.event_id(i)+".csv");
 assert(sha256File(file)==waves.sha256(i),'ICNN:WaveformChanged','Waveform file changed after identity verification: %s',file);
 files(end+1,1)=string(file);
end
files=sort(unique(files));hashes=strings(numel(files),1);
for i=1:numel(files);hashes(i)=sha256File(files(i));end
manifest=table(files,hashes);configuration=jsonencode(cfg);existing=fullfile(runRoot,'manifest.mat');
if isfile(existing)
 old=load(existing);assert(isequal(old.manifest,manifest)&&strcmp(old.configuration,configuration),'ICNN:ManifestMismatch','Code, data, protocol or config changed. Use a new run directory.');
else
 assert(isempty(dir(fullfile(runRoot,'**','*.mat'))),'ICNN:UnverifiedCheckpoint','Existing MAT artifacts without matching manifest are prohibited.');
 save(existing,'manifest','configuration');writetable(manifest,fullfile(runRoot,'manifest.csv'));
end
signature=sha256File(existing);
end
