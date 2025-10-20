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

payload_len = size(mpdusPayload, 2);
mcus = zeros(size(mpdusPayload), 'uint8');
for i = 1:size(mpdusPayload,1)
    P = mpduPointerDec(i);
    startByte = P + 1;
    mcus(i,1:(payload_len - P)) = mpdusPayload(i, startByte:end);
end

mcusApids = unique(mcus(:,2));
mcusSorted = cell(1, numel(mcusApids));
mcusSortedFollowup = cell(1, numel(mcusApids));
mcusSortedLengthDec = cell(1, numel(mcusApids));
mcusSortedPayload = cell(1, numel(mcusApids));
mcusSortedCounterDec = cell(1, numel(mcusApids));

for i = 1:numel(mcusApids)
    apid = mcusApids(i);
    rows = mcus(:,2) == apid;
    mcusSorted{i} = mcus(rows, :);
    mcusHeader = mcusSorted{i}(:,3:4);
    mcusHeaderBits = int2bit(mcusHeader.', 8).';
    mcusCounterBits = mcusHeaderBits(:,3:end);
    mcusSortedCounterDec{i} = bi2de(mcusCounterBits, 'left-msb');
    mcusSortedFollowup{i} = mcusHeaderBits(:,1:2);
    mcusLength = mcusSorted{i}(:,5:6);
    mcusLength = int2bit(mcusLength.', 8).';
    mcusSortedLengthDec{i} = bi2de(mcusLength, 'left-msb');
    mcusSortedPayload{i} = mcusSorted{i}(:,18:end);
end



dataAll = mcus;           % alle Zeilen für diesen APID
numRows = size(dataAll, 1);

allBlocks = cell(numRows, 1);      % alle Blöcke pro Zeile (variable Länge)
allMatrices = {};                  % später alle Zeilen als numerische Zeilenmatrix

for r = 1:numRows
    zeile1 = dataAll(r, :);        % aktuelle Zeile (Byte-Stream)
    lenValPos = [5 6];             % Position der Längenbytes
    index1 = 1;

    blocks = {};                   % Cell-Array für Blöcke
    maxLen = 0;                    % längster Block in dieser Zeile

    while lenValPos(2) <= numel(zeile1)
        % === 1) Länge aus zwei Bytes (Big-Endian, left-msb) ===
        mcusLength = double(zeile1(lenValPos));           % zwei Bytes
        mcusLengthBits = int2bit(mcusLength.', 8).';      % 16 Bits (2x8)
        lenVal = bi2de(mcusLengthBits, 'left-msb');       % dezimaler Längenwert

        % === 2) Endposition berechnen ===
        index2 = lenValPos(2) + lenVal + 1;

        if index2 > numel(zeile1)
            index2 = numel(zeile1);
        end

        % === 3) Block ausschneiden ===
        block = zeile1(index1:index2);
        blocks{end+1} = block;
        maxLen = max(maxLen, numel(block));

        % === 4) Indexe aktualisieren ===
        index1 = index2 + 1;       % Start für nächsten Block
        lenValPos = index1 + [4 5];% 5. und 6. Byte des neuen Blocks

        if lenValPos(2) > numel(zeile1)
            break;
        end
    end

    % === 5) In Matrix umwandeln (mit 0 auffüllen) ===
    numBlocks = numel(blocks);
    matrix = zeros(numBlocks, maxLen, 'like', zeile1);

    for i = 1:numBlocks
        bl = blocks{i};
        matrix(i, 1:numel(bl)) = bl;
    end

    % speichern
    allBlocks{r} = blocks;    % Originalblöcke
    allMatrices{r} = matrix;  % Matrix für diese Zeile
end

% === 6) Optional: alles in eine große Matrix mit Spalten zusammenführen ===
% gleiche Spaltenbreite erzwingen (mit 0 auffüllen)
maxCols = max(cellfun(@(m) size(m, 2), allMatrices));
totalRows = sum(cellfun(@(m) size(m, 1), allMatrices));
combinedMatrix = zeros(totalRows, maxCols, 'like', dataAll);

rowOffset = 0;
for r = 1:numRows
    m = allMatrices{r};
    n = size(m, 1);
    combinedMatrix(rowOffset+1:rowOffset+n, 1:size(m,2)) = m;
    rowOffset = rowOffset + n;
end

% === 7) Zeilen löschen, die mit 0 beginnen ===
zeroStartRows = combinedMatrix(:,1) == 0;  % logischer Index für Zeilen, deren erstes Element 0 ist
combinedMatrix(zeroStartRows, :) = [];     % diese Zeilen löschen



% fin = double(cadus(:,5:end)).';
% for col = 1:23                                  % column number = VCDU frame number
%     first_head = fin(9,col)*256 + fin(10,col);  % 70 for column 11
%     fin([1:first_head+1]+9, col)';              % beginning of line 11: 1st header in 70
%     fin([1:22]+double(first_head)+11, col)';            % start of MCU of line 11
% 
%     % clear l secondary apid m
%     l = fin(first_head+16-1, col)*256 + fin(first_head+16, col);  % vector of packet lengths
%     secondary = fin(first_head+16-5, col);                        % initializes header list
%     apid = fin(first_head+16-4, col);                             % initializes APID list
%     m = fin([first_head+12:first_head+12], col);
%     k = 1;
% 
%     while ((sum(l)+(k)*7+first_head+12) < (1020-128))
%         m = [m fin([first_head+12:first_head+12] + sum(l) + (k)*7, col)];
%         secondary(k+1) = fin(first_head+16 + sum(l) + (k)*7 - 5, col);
%         apid(k+1) = fin(first_head+16 + sum(l) + (k)*7 - 4, col);
%         l(k+1) = fin(first_head+16-1 + sum(l) + (k)*7, col)*256 + ...
%                   fin(first_head+16 + sum(l) + (k)*7, col);
%         % 16 = offset from VDU beginning
%         k = k + 1;
%     end
% 
%     for k = 1:length(l)-1                       % saves each MCU bytes in a new file
%         jpeg = fin([1:l(k)] + first_head + 12 + 19 + sum(l(1:k-1)) - 1 + 7*(k-1), col);
%         f = fopen(['jpeg', num2str(apid(k), '%03d'), '_', ...
%                    num2str(col, '%03d'), '_', num2str(k, '%03d'), '.bin'], 'w');
%         fwrite(f, jpeg, 'uint8');
%         fclose(f);
%     end
% end
