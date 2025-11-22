clear; clc; close all;
tic

%% get config
[~,Params,~,~,~,ReedSolomon,Huffman,DCT] = getconfig();

%% cadu extraction
filename = 'data/meteor_m2.cadu';
fid = fopen(filename,'rb');
data = fread(fid,inf,'uint8');
fclose(fid);

dataBits = de2bi(data, 8, 'left-msb');
dataBits = reshape(dataBits.', [], 1);
dataBits = 2*double(dataBits)-1;

syncAsm = '1ACFFC1D';
syncAsmBytes = sscanf(syncAsm, '%2x');
syncAsmBits = de2bi(syncAsmBytes, 8, 'left-msb');
syncAsmBits = reshape(syncAsmBits.', [], 1);
syncAsmBits = 2*double(syncAsmBits)-1;

[corr, lags] = xcorr(dataBits, syncAsmBits);

sync = uint8([0x1A 0xCF 0xFC 0x1D]);
mask = (data(1:end-3)==sync(1)) & (data(2:end-2)==sync(2)) & ...
       (data(3:end-1)==sync(3)) & (data(4:end)==sync(4));
syncIdx = find(mask);
caduLength = 1024;
numCadus = numel(syncIdx);

cadus = zeros(numCadus,caduLength,'uint8');
for i = 1:numCadus
    s = syncIdx(i);
    if s+caduLength-1 <= numel(data)
        cadus(i,:) = data(s:s+caduLength-1);
    end
end
cvcdus = cadus(:,5:end);

% mcu extraction
[mcus, qualityFactors, apids] = extraction(cvcdus);

% jpeg decoding
Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params);

% cat rgb 
h = min([size(Images.jpeg64,1), size(Images.jpeg65,1), size(Images.jpeg68,1)]);
w = 1568;

R = Images.jpeg64(1:h, 1:w);
G = Images.jpeg65(1:h, 1:w);
B = Images.jpeg68(1:h, 1:w);

% Images.rgb = cat(3, B, G, R);      
% 
% figure;
% imshow(Images.rgb);
% title('RGB (beschnitten)')

toc