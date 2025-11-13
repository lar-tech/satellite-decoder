clear; clc; close all;

%% cadu extraction
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

%% partial packet extraction
pp = extraction(cvcdus);

% sort apids
apids = cellfun(@(x) x(2), pp);
uniqueApids = unique(apids);
ppSorted = cell(1, numel(uniqueApids));
for i = 1:numel(uniqueApids)
    apid = uniqueApids(i);
    rows = (apids == apid);
    ppSorted{i} = pp(rows);
end

%% mcus
mcusSorted = cell(1, numel(ppSorted));
qualityFactor = cell(1, numel(ppSorted));
for i = 1:numel(ppSorted)
    for j = 1:numel(ppSorted{i})
        qualityFactor{i}{j} = ppSorted{i}{j}(1,20);
        mcusSortedDec = ppSorted{i}{j}(1,21:end);
        mcusSorted{i}{j} = int2bit(mcusSortedDec.', 8).';
    end
end


%% jpeg decoding
Huffman.lDc.lengths = [0 1 5 1 1 1 1 1 1 0 0 0 0 0 0 0];
Huffman.lDc.symbols = uint8([0x00 0x01 0x02 0x03 0x04 0x05 0x06 0x07 0x08 0x09 0x0A 0x0B]);

Huffman.lAc.lengths = [0 2 1 3 3 2 4 3 5 5 4 4 0 0 1 0x7D];
Huffman.lAc.symbols = uint8([
                        0x01 0x02 0x03 0x00 0x04 0x11 0x05 0x12 0x21 0x31 0x41 0x06 0x13 0x51 0x61 0x07 ...
                        0x22 0x71 0x14 0x32 0x81 0x91 0xA1 0x08 0x23 0x42 0xB1 0xC1 0x15 0x52 0xD1 0xF0 ...
                        0x24 0x33 0x62 0x72 0x82 0x09 0x0A 0x16 0x17 0x18 0x19 0x1A 0x25 0x26 0x27 0x28 ...
                        0x29 0x2A 0x34 0x35 0x36 0x37 0x38 0x39 0x3A 0x43 0x44 0x45 0x46 0x47 0x48 0x49 ...
                        0x4A 0x53 0x54 0x55 0x56 0x57 0x58 0x59 0x5A 0x63 0x64 0x65 0x66 0x67 0x68 0x69 ...
                        0x6A 0x73 0x74 0x75 0x76 0x77 0x78 0x79 0x7A 0x83 0x84 0x85 0x86 0x87 0x88 0x89 ...
                        0x8A 0x92 0x93 0x94 0x95 0x96 0x97 0x98 0x99 0x9A 0xA2 0xA3 0xA4 0xA5 0xA6 0xA7 ...
                        0xA8 0xA9 0xAA 0xB2 0xB3 0xB4 0xB5 0xB6 0xB7 0xB8 0xB9 0xBA 0xC2 0xC3 0xC4 0xC5 ...
                        0xC6 0xC7 0xC8 0xC9 0xCA 0xD2 0xD3 0xD4 0xD5 0xD6 0xD7 0xD8 0xD9 0xDA 0xE1 0xE2 ...
                        0xE3 0xE4 0xE5 0xE6 0xE7 0xE8 0xE9 0xEA 0xF1 0xF2 0xF3 0xF4 0xF5 0xF6 0xF7 0xF8 ...
                        0xF9 0xFA
                        ]);

DCT.zigzagTable =   [
                    0  1  5  6 14 15 27 28;
                    2  4  7 13 16 26 29 42;
                    3  8 12 17 25 30 41 43;
                    9 11 18 24 31 40 44 53;
                    10 19 23 32 39 45 52 54;
                    20 22 33 38 46 51 55 60;
                    21 34 37 47 50 56 59 61;
                    35 36 48 49 57 58 62 63
                    ];

DCT.zigzagTableReversed =   [
                             0  1  8 16  9  2  3 10;
                            17 24 32 25 18 11  4  5;
                            12 19 26 33 40 48 41 34;
                            27 20 13  6  7 14 21 28;
                            35 42 49 56 57 50 43 36;
                            29 22 15 23 30 37 44 51;
                            58 59 52 45 38 31 39 46;
                            53 60 61 54 47 55 62 63
                            ];

DCT.quantizationTable = [
                        16 11 10 16 24 40 51 61;
                        12 12 14 19 26 58 60 55;
                        14 13 16 24 40 57 69 56;
                        14 17 22 29 51 87 80 62;
                        18 22 37 56 68 109 103 77;
                        24 35 55 64 81 104 113 92;
                        49 64 78 87 103 121 120 101;
                        72 92 95 98 112 100 103 99
                        ];

% jpegImage = imaging(mcusSorted, Huffman, DCT);

% calculate magnitude
function magnitude = decodeMagnitude(codeWord, bitArray)
    if codeWord == 0
        magnitude = 0;
    end
    bitsVal = double(bi2de(bitArray, 'left-msb'));
    if bitArray(1) == 1
        magnitude = bitsVal;
    else
        magnitude = -((2^double(codeWord) - 1) - bitsVal);
    end
end

[DCMap, ACMap] = huffman(Huffman);

% huffman, run-size decoding
magnitudes = cell(1, 4);
for i = 1:4
    for j = 1:numel(mcusSorted{i})
        magnitudes{i}{j} = zeros(1, 64);
    end
end

for i = 1:numel(mcusSorted)
    for j = 1:numel(mcusSorted{i})
        mcu = mcusSorted{i}{j};
        pos = 1;

        % DC Part
        for k = 1:9
            key = sprintf('%d', mcu(pos:pos+k-1));
            if isKey(DCMap.symbols,key)
                nextSymbolLength = double(DCMap.symbols(key));
                if nextSymbolLength ~= 0 % EOB
                    bitArray = mcu(pos+k:pos+k+nextSymbolLength-1);
                    dcMagnitude = decodeMagnitude(nextSymbolLength, bitArray);
                    break;
                else
                    dcMagnitude = 0;
                end
            end
        end
        pos = pos + k + nextSymbolLength;

        % AC Part
        acMagnitudes = zeros(1,63);
        acCount = 1;
        while pos <= numel(mcu)
            found = false;
            for k = 1:min(16, numel(mcu)-pos+1)
                key = sprintf('%d', mcu(pos:pos+k-1));
                if isKey(ACMap.symbols,key)
                    if strcmp(ACMap.symbols(key), '0/0') % EOB
                        break; 
                    elseif strcmp(ACMap.symbols(key), '15/0') % ZRL 
                        acCount = acCount + 16;
                        pos = pos + 11;
                        found = true;
                        break;
                    end
                    
                    if pos+k+double(ACMap.symbols(key))-1 > numel(mcu)
                        break;  % end
                    end
                    runsize = str2double(split(ACMap.symbols(key), '/'));
                    acCount = acCount + runsize(1);
                    nextSymbolLength = runsize(2);
                    bitArray = mcu(pos+k:pos+k+nextSymbolLength-1);
                    acMagnitudes(acCount) = decodeMagnitude(nextSymbolLength, bitArray);
                    acCount = acCount + 1;
                    pos = pos + k + nextSymbolLength;
                    found = true;
                    break;
                end
            end
            if ~found, break; end
            if ACMap.symbols(key) == 240, continue; end
        end
        magnitudes{i}{j} = [dcMagnitude, acMagnitudes];
    end
end

% differential encoding of DC values
for i = 1:numel(magnitudes)
    dcValues = zeros(1, numel(magnitudes{i}));
    for j = 1:numel(magnitudes{i})
        if j == 1 || mod(j,14) == 0
            dcValues(j) = magnitudes{i}{j}(1);
        else
            dcValues(j) = dcValues(j-1) + magnitudes{i}{j}(1);
        end
    end

    for j = 1:numel(magnitudes{i})
        magnitudes{i}{j}(1) = dcValues(j);
    end
end

% quality factor
F = cell(1, numel(qualityFactor));
for i = 1:numel(qualityFactor)
    for j = 1:numel(qualityFactor{i})
        if 20 < qualityFactor{i}{j} && qualityFactor{i}{j} < 50
            F{i}{j} = 5000 / qualityFactor{i}{j};
        elseif 50 <= qualityFactor{i}{j} && qualityFactor{i}{j} <= 100
            F{i}{j} = 200 - 2 * qualityFactor{i}{j};
        else
            F{i}{j} = 100;
        end
    end
end

% zig-zag, dct decoding
% idx = 5;
% magnitude = magnitudes{1}{idx};
% zigzag = zeros(8,8);
% 
% for k = 0:63
%     [r, c] = find(DCT.zigzagTableReversed == k);
%     zigzag(r,c) = magnitude(k+1); 
% end
% zigzagQuant = zigzag .* DCT.quantizationTable * double(F{1}{idx})/100;
% spatials = idct2(zigzagQuant) + 128;


spatials = cell(1, 4);
for i = 1:4
    for j = 1:numel(magnitudes{i})
        spatials{i}{j} = zeros(1, 64);
    end
end
for i = 1:numel(magnitudes)
    for j = 1:numel(magnitudes{i})
        magnitude = magnitudes{i}{j};
        zigzag = zeros(8,8);
        for k = 0:63
            [r, c] = find(DCT.zigzagTableReversed == k);
            zigzag(r,c) = magnitude(k+1);
        end
        zigzagQuant = zigzag .* DCT.quantizationTable * double(F{i}{j})/100;
        spatials{i}{j} = idct2(zigzagQuant) + 128;
    end
end

% % combine image
% jpegImage = [];
% for i = 1:14
%     mcu = [];
%     for j = 1:14
%         mcu = [mcu, spatials{i}{j}];
%     end
%     jpegImage = [jpegImage; mcu];
% end
% imshow(uint8(jpegImage))

for i = 1:numel(spatials)
    spatial = spatials{i};
    blockSize = 8;
    blocksPerRow = 14;
    numBlocks = numel(spatial);
    numRows = ceil(numBlocks / blocksPerRow);
    combined = zeros(numRows * size(spatial{1}, 1), blocksPerRow * blockSize);

    idx = 1;
    for row = 1:numRows
        for col = 1:blocksPerRow
            if idx > numBlocks
                break;
            end
            yStart = (row-1)*blockSize + 1;
            yEnd   = row*blockSize;
            xStart = (col-1)*blockSize + 1;
            xEnd   = col*blockSize;
            combined(yStart:yEnd, xStart:xEnd) = spatial{idx};
            idx = idx + 1;
        end
    end
    jpegImage = uint8(combined);
    figure(i);
    imshow(jpegImage);
end
