function cfg=configureVerifiedInputs(cfg,sourceRoot)
[p,~]=verifiedProtocol(sourceRoot);
cfg.metadataPath=fullfile(sourceRoot,'metadata','metadata_verified.csv');
cfg.csvFolder=char(p.waveform_dir);assert(isfolder(cfg.csvFolder));
cfg.filterExistingCSVOnly=false;cfg.usePArrivalFromMetadata=false;
cfg.sourceProtocolHash=char(sha256File(fullfile(sourceRoot,'protocol.json')));
cfg.sourceProtocol='stead-source-verified-v2';cfg.verifiedSourceRoot=char(sourceRoot);
end
