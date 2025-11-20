clear; clc; close all;
tic

%% get config
[~,Params,~,~,~,ReedSolomon,Huffman,DCT] = getconfig();

%% cadu extraction
filename = 'data/meteor_m2.cadu';
fid = fopen(filename,'rb');
data = fread(fid,inf,'uint8');
fclose(fid);

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

% %% reed-solomon correction
% % de-interleaving
% deinterleavedBlocks = zeros(size(cvcdus, 1), ReedSolomon.interleavingDepth, ReedSolomon.codeWordLength, 'uint8');
% for i = 1:size(cvcdus, 1)
%     cvcdu = cvcdus(i, :);
%     for j = 1:ReedSolomon.interleavingDepth
%         deinterleavedBlocks(i, j, :) = cvcdu(j:ReedSolomon.interleavingDepth:end);
%     end
% end
% 
% % reed-solomon decoder
% generatorPolynomial = rsgenpoly( ...
%                         ReedSolomon.codeWordLength, ...
%                         ReedSolomon.messageLength, ...
%                         bi2de(ReedSolomon.primitivePolynomial, ...
%                         'left-msb'));
% rsDec = comm.RSDecoder( ...
%             'CodewordLength', ReedSolomon.codeWordLength, ...
%             'MessageLength', ReedSolomon.messageLength, ...   
%             'GeneratorPolynomialSource', 'Property', ...
%             'GeneratorPolynomial', generatorPolynomial, ...
%             'PrimitivePolynomialSource', 'Property', ...
%             'PrimitivePolynomial', ReedSolomon.primitivePolynomial ...
%         );
% correctedBlocks = zeros(size(deinterleavedBlocks, 1), ReedSolomon.interleavingDepth, ReedSolomon.messageLength, 'uint8');
% numErrors       = zeros(size(deinterleavedBlocks, 1), ReedSolomon.interleavingDepth);
% for i = 1:size(deinterleavedBlocks, 1)
%     for j = 1:ReedSolomon.interleavingDepth
%         [decoded, errCount] = rsDec(squeeze(deinterleavedBlocks(i, j, :)));
%         correctedBlocks(i, j, :) = decoded;
%         numErrors(i, j) = errCount;
%         fprintf('Frame %d, Block %d: %d Bytefehler korrigiert\n', i, j, errCount);
%     end
% end
% 
% % re-interleaving
% reinterleavedBytes = zeros(size(correctedBlocks, 1), ReedSolomon.interleavingDepth * ReedSolomon.messageLength, 'uint8');
% for i = 1:size(correctedBlocks, 1)
%     correctedBlock = squeeze(correctedBlocks(i, :, :));
%     reinterleavedBytes(i, :) = reshape(correctedBlock.', 1, []);
% end
% bitsPerByte = 8;
% reinterleavedBits = de2bi(reinterleavedBytes, bitsPerByte, 'left-msb');
% reinterleavedBits = reshape(reinterleavedBits.', size(correctedBlocks, 1), []);
% vcdus = logical(reinterleavedBits);

% mcu extraction
[mcus, qualityFactors, apids] = extraction(cvcdus);

%% jpeg decoding
% Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params);

% % cat rgb 
% h = min([size(Images.jpeg64,1), size(Images.jpeg65,1), size(Images.jpeg68,1)]);
% w = 1568;
% 
% R = Images.jpeg64(1:h, 1:w);
% G = Images.jpeg65(1:h, 1:w);
% B = Images.jpeg68(1:h, 1:w);
% 
% Images.rgb = cat(3, B, G, R);      
% 
% figure;
% imshow(Images.rgb);
% title('RGB (beschnitten)')

toc