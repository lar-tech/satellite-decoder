filename = 'data/meteor_m2_lrpt.cadu';
fid = fopen(filename, 'rb');
data = fread(fid, inf, 'uint8');
fclose(fid);

sync = uint8([0x1A, 0xCF, 0xFC, 0x1D]);
mask = ...
    (data(1:end-3) == sync(1)) & ...
    (data(2:end-2) == sync(2)) & ...
    (data(3:end-1) == sync(3)) & ...
    (data(4:end)   == sync(4));

sync_indices = find(mask);

fprintf('Gefundene Syncwörter: %d\n', numel(sync_indices));
disp('Erste 5 Positionen:');
disp(sync_indices(1:min(5,end)));