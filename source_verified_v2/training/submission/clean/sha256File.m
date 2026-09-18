function hash = sha256File(path)
md=java.security.MessageDigest.getInstance('SHA-256');
fid=fopen(path,'rb');assert(fid>=0,'Cannot read file for hashing.');c=onCleanup(@()fclose(fid));
while ~feof(fid)
    b=fread(fid,1024*1024,'*uint8');md.update(typecast(b,'int8'));
end
v=typecast(md.digest(),'uint8');hash=string(lower(reshape(dec2hex(v,2)',1,[])));
end
