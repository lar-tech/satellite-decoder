clear; clc; close all;

%% Frame Extraction
filename = 'data/meteor_m2_lrpt.cadu';
fid = fopen(filename,'rb');
data = fread(fid,inf,'uint8');
fclose(fid);

sync = uint8([0x1A 0xCF 0xFC 0x1D]);
mask = (data(1:end-3)==sync(1)) & (data(2:end-2)==sync(2)) & ...
       (data(3:end-1)==sync(3)) & (data(4:end)==sync(4));
sync_idx = find(mask);
caduLength = 1024;
numCadus = numel(sync_idx);

cadus = zeros(numCadus,caduLength,'uint8');
for i = 1:numCadus
    s = sync_idx(i);
    if s+caduLength-1 <= numel(data)
        cadus(i,:) = data(s:s+caduLength-1);
    end
end

cvcdus = cadus(:,5:end);
vcdus = cvcdus(:,1:end-128);
mpdus = vcdus(:,9:end);
mpdusPayload = mpdus(:,3:end);
mpdusHeader = mpdus(:,1:2);
mpdusHeaderBits = int2bit(mpdusHeader.', 8).';
mpduPointer = mpdusHeaderBits(:,6:end);
mpduPointerDec = bi2de(mpduPointer, 'left-msb');


mcus = {};

P = mod(mpduPointerDec(1), 2048);
idx = double(P + 1);
i = 1;
row = 1;
totalLen = 0;

while sum(cellfun(@numel, mcus)) < numel(mpdusPayload)
    if idx+4 > size(mpdusPayload, 2)
        part1 = mpdusPayload(row, idx:end);
        lenBytes = mpdusPayload(row+1, 5-size(part1,2) : 6-size(part1,2));
        lenBits = int2bit(lenBytes.', 8).';
        lenDec = double(bi2de(lenBits, 'left-msb'));
        totalLen = 6 + lenDec + 1;
        idx = totalLen-size(part1,2)+1;
        part2 = mpdusPayload(row+1, 1:idx);
        mcus{i} = [part1, part2];
        row = row+1;
    else
        lenBytes = mpdusPayload(row, idx+4 : idx+5);
        lenBits = int2bit(lenBytes.', 8).';
        lenDec = double(bi2de(lenBits, 'left-msb'));
        totalLen = 6 + lenDec + 1;
    
        remaining = size(mpdusPayload, 2) - idx + 1;
        
        if remaining > totalLen
            mcus{i} = mpdusPayload(row, idx : idx+totalLen-1);
            idx = idx+totalLen;
        elseif remaining == totalLen
            mcus{i} = mpdusPayload(row, idx:end);
            P = mod(mpduPointerDec(row+1), 2048);
            idx = double(P + 1);
            row = row + 1;
        else
            if row < size(mpdusPayload, 2)
                part1 = mpdusPayload(row, idx:end);
                part2 = mpdusPayload(row+1, 1 : totalLen - numel(part1));
                mcus{i} = [part1, part2];
                P = mod(mpduPointerDec(row+1), 2048);
                idx = double(P + 1);
                row = row + 1;
            else
                mcus{i} = mpdusPayload(row, idx:end);
            end
        end
    end
    i = i+1;
end
