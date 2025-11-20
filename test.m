clc; clear;

load("data/cvcdus.mat")

% reed-solomon
ReedSolomon.interleavingDepth = 4;
ReedSolomon.codeWordLength = 255;                       
ReedSolomon.messageLength = 223;                        
ReedSolomon.primitivePolynomial = [1 1 0 0 0 0 1 1 1];  % x^8+x^7+x^2+x+1
ReedSolomon.E = 16;

N = ReedSolomon.codeWordLength;
K = ReedSolomon.messageLength;
prim_poly = bi2de(ReedSolomon.primitivePolynomial, 'left-msb');
genpoly = rsgenpoly(N,K,prim_poly);

%% reed-solomon
% de-interleaving
deinterleavedBlocks = zeros(size(cvcdus, 1), ReedSolomon.interleavingDepth, ReedSolomon.codeWordLength, 'uint8');
for i = 1:size(cvcdus, 1)
    cvcdu = cvcdus(i, :);
    for j = 1:ReedSolomon.interleavingDepth
        deinterleavedBlocks(i, j, :) = cvcdu(j:ReedSolomon.interleavingDepth:end);
    end
end

% reed-solomon decoder
rsDec = comm.RSDecoder( ...
            'CodewordLength', ReedSolomon.codeWordLength, ...
            'MessageLength', ReedSolomon.messageLength, ...
            'GeneratorPolynomialSource', 'Property', ...
            'GeneratorPolynomial', genpoly, ...
            'PrimitivePolynomialSource', 'Property', ...
            'PrimitivePolynomial', ReedSolomon.primitivePolynomial ...
        );
correctedBlocks = zeros(size(deinterleavedBlocks, 1), ReedSolomon.interleavingDepth, ReedSolomon.messageLength, 'uint8');
numErrors       = zeros(size(deinterleavedBlocks, 1), ReedSolomon.interleavingDepth);
for i = 1:size(deinterleavedBlocks, 1)
    for j = 1:ReedSolomon.interleavingDepth
        [decoded, errCount] = rsDec(squeeze(deinterleavedBlocks(i, j, :)));
        correctedBlocks(i, j, :) = decoded;
        numErrors(i, j) = errCount;
        fprintf('Frame %d, Block %d: %d Bytefehler korrigiert\n', i, j, errCount);
    end
end

% re-interleaving
reinterleavedBytes = zeros(size(correctedBlocks, 1), ReedSolomon.interleavingDepth * ReedSolomon.messageLength, 'uint8');
for i = 1:size(correctedBlocks, 1)
    correctedBlock = squeeze(correctedBlocks(i, :, :));
    reinterleavedBytes(i, :) = reshape(correctedBlock.', 1, []);
end
bitsPerByte = 8;
reinterleavedBits = de2bi(reinterleavedBytes, bitsPerByte, 'left-msb');
reinterleavedBits = reshape(reinterleavedBits.', size(correctedBlocks, 1), []);
vcdus = logical(reinterleavedBits);

% 
% %% extraction
% % extract header infos
% vcdus = cvcdus(:,1:end-128);
% mpdus = vcdus(:,9:end);
% mpdusPayload = mpdus(:,3:end);
% mpdusHeader = mpdus(:,1:2);
% mpdusHeaderBits = int2bit(mpdusHeader.', 8).';
% mpduPointer = mpdusHeaderBits(:,6:end);
% mpduPointerDec = bi2de(mpduPointer, 'left-msb');
% 
% pp = {};
% row = 1;
% i = 1;
% idx = double(mod(mpduPointerDec(1), 2048) + 1);
% while sum(cellfun(@numel, pp)) < numel(mpdusPayload)
%     % Check: header continues onto the next row
%     if idx+4 > size(mpdusPayload, 2)
%         % header spans across row and row + 1
%         part1 = mpdusPayload(row, idx:end);
%         lenBytes = mpdusPayload(row+1, 5-size(part1,2):6-size(part1,2));
%         lenBits = int2bit(lenBytes.', 8).';
%         lenDec = double(bi2de(lenBits, 'left-msb'));
%         totalLen = 6 + lenDec + 1;
%         idx = totalLen - size(part1,2) + 1;
%         part2 = mpdusPayload(row+1, 1:idx);
%         pp{i} = [part1, part2];
%         row = row + 1;
% 
%     else
%         % header fully contained in current row
%         lenBytes = mpdusPayload(row, idx+4:idx+5);
%         lenBits = int2bit(lenBytes.', 8).';
%         lenDec = double(bi2de(lenBits, 'left-msb'));
%         totalLen = 6 + lenDec + 1;
%         remaining = size(mpdusPayload, 2) - idx + 1;
%         if remaining > totalLen
%             % standard case
%             pp{i} = mpdusPayload(row, idx:idx+totalLen-1);
%             idx = idx+totalLen;
% 
%         elseif remaining == totalLen
%             % no follow-up packet -> packet ends perfectly
%             pp{i} = mpdusPayload(row, idx:end);
%             idx = double(mod(mpduPointerDec(row+1), 2048) + 1);
%             row = row + 1;
% 
%         elseif row < size(mpdusPayload, 1)
%             % overflow into next row
%             part1 = mpdusPayload(row, idx:end);
%             part2 = mpdusPayload(row+1, 1 : totalLen - numel(part1));
%             pp{i} = [part1, part2];
%             P = mod(mpduPointerDec(row+1), 2048);
%             idx = double(P + 1);
%             row = row + 1;
%         else
%             % last incomplete mcu
%             pp{i} = mpdusPayload(row, idx:end);
%         end
%     end
%     i = i+1;
% end
% % extract mcus
% mcus = cell(1, numel(pp));
% qualityFactors = cell(1, numel(pp));
% apids = zeros(1, numel(pp));
% for i = 1:numel(pp)
%     apids(i) = pp{i}(2);
%     qualityFactors{i} = pp{i}(1,20);
%     mcusDec = pp{i}(1,21:end);
%     mcus{i} = int2bit(mcusDec.', 8).';
% end