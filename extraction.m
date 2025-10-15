clear; clc; close all;
verif = true;

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



packetBuffer = uint8([]);
mcus = {}; 
k = 1;

for i = 1:size(mpdus,1)
    P = mpduPointerDec(i);

    if P == 2047
        packetBuffer = [packetBuffer, mpdusPayload(i,:)];
    else
        if P > 0
            packetBuffer = [packetBuffer, mpdusPayload(i,1:P)];
        end
        while numel(packetBuffer) >= 6
            header = packetBuffer(1:6);
            lenField = bitshift(uint16(header(5)),8) + uint16(header(6));
            totalLen = double(lenField) + 7;  % 6 Header + lenField+1
            if numel(packetBuffer) < totalLen
                break; % MCU noch unvollständig
            end
            mcus{k} = packetBuffer(1:totalLen);
            packetBuffer = packetBuffer(totalLen+1:end);
            k = k + 1;
        end
        packetBuffer = [packetBuffer, mpdusPayload(i,P+1:end)];
    end
end