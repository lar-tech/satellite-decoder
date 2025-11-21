close all; clear; clc;
tic 

% get config
[Data, Params, Rcc, Viterbi, Descrambler, ReedSolomon, Huffman, DCT] = getconfig(); 
% 
% numberBlocks = round(Data.fileSize / Data.blockSize);
% Data.blockSize = int64(Data.fileSize / numberBlocks);
% % numberBlocks = round(Data.fileSize / Data.blockSize);
Data.blockSize = 100000;

softBitsAll = [];
counter = 0;
for i = 1:Data.blockSize+1:Data.fileSize
    % demodulate qpsk
    symbols = demod(i, Data, Params, Rcc);

    % find constellation
    softBits = constellation(counter, symbols, Params);
    softBitsAll = [softBitsAll; softBits];
    counter = counter + 1;
    % if counter == 89
    %     break
    % end
    % [cvcdus, payloads, decodedBits] = decode(softBitsAll, Viterbi, Descrambler, Params);
end

% decoding and descrambling
[cvcdus, payloads, decodedBits] = decode(softBitsAll, Viterbi, Descrambler, Params);

% % % mcu extraction
% [mcus, qualityFactors, apids] = extraction(cvcdus);
% % 
% % % jpeg decoding
% Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params);

toc