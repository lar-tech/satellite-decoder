clear; clc; close all;
verif = true;

%% === Frame Extraction ===
filename = 'data/meteor_m2_lrpt.cadu';
fid = fopen(filename,'rb');
data = fread(fid,inf,'uint8');
fclose(fid);

sync = uint8([0x1A 0xCF 0xFC 0x1D]);
mask = (data(1:end-3)==sync(1)) & (data(2:end-2)==sync(2)) & ...
       (data(3:end-1)==sync(3)) & (data(4:end)==sync(4));
sync_idx = find(mask);
frame_len = 1024;
num_frames = numel(sync_idx);

frames = zeros(num_frames,frame_len,'uint8');
for i = 1:num_frames
    s = sync_idx(i);
    if s + frame_len - 1 <= numel(data)
        frames(i,:) = data(s:s+frame_len-1);
    end
end

%% === Pointer Calculation (11-bit FHP) ===
pointer_raw = double(frames(:,13))*256 + double(frames(:,14));
pointer = bitand(pointer_raw, 2047);   % 0x07FF → nur 11 Bit gültig

if verif
    fprintf('Loaded %d frames of %d bytes each\n', num_frames, frame_len);
    fprintf('First 4 bytes (ASM): %s\n', sprintf('%02X ', frames(1,1:4)));
    fprintf('Pointer range: min=%d, max=%d\n', min(pointer), max(pointer));
end

%% M-PDU Extraction 
m_pdu_data = {};
apid_list  = [];

for i = 1:num_frames
    lo = 17; 
    hi = frame_len - 5;  

    found = false;
    for p = lo:hi
        b1 = frames(i,p); b2 = frames(i,p+1); b3 = frames(i,p+2); b4 = frames(i,p+3); b5 = frames(i,p+4); b6 = frames(i,p+5);

        version = bitshift(b1, -5);  
        if version ~= 0, continue; end

        apid = bitand( bitor( bitshift(uint16(b1),8), uint16(b2) ), uint16(2047) ); % 11-bit
        if ~(ismember(apid, [64 65 66 67 68 70 71]))
            continue;
        end


        pkt_len = double( bitshift(uint16(b5),8) + uint16(b6) ) + 7; 
        if p + pkt_len - 1 > frame_len
            continue; 
        end

        m_pdu_data{end+1} = frames(i, p : p + pkt_len - 1);
        apid_list(end+1)  = apid;
        found = true;
        break;
    end
end