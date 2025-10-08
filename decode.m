clear; clc; close all;

%% CADU-Frames einlesen
filename = 'data/meteor_m2_lrpt.cadu';
fid = fopen(filename,'rb');  data = fread(fid,inf,'uint8');  fclose(fid);
fprintf('File loaded: %d bytes\n',numel(data));

sync = uint8([0x1A 0xCF 0xFC 0x1D]);
mask = (data(1:end-3)==sync(1)) & (data(2:end-2)==sync(2)) & ...
       (data(3:end-1)==sync(3)) & (data(4:end)==sync(4));
sync_idx = find(mask);
frame_len = 1024;
num_frames = numel(sync_idx);
fprintf('Found %d sync words.\n',num_frames);

frames = zeros(num_frames,frame_len,'uint8');
for i=1:num_frames
    s = sync_idx(i);
    if s+frame_len-1 <= numel(data)
        frames(i,:) = data(s:s+frame_len-1);
    end
end
assert(all(frames(1,1:4)==[26 207 252 29]),'ASM mismatch – check alignment.');

%% Pointer on M-PDU
pointer = double(frames(:,14)).*256 + double(frames(:,15)) + 12;



