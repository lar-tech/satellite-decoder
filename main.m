close all; clear; clc;

% get config
[Data, Params, Rcc, Viterbi, Descrambler, ReedSolomon, Huffman, DCT] = getconfig(); 

N = round(Data.fileSize / Data.blockSize);
Data.blockSize = int64(Data.fileSize / N);
for i = 1:Data.blockSize:Data.fileSize-Data.blockSize
    % demodulate qpsk
    symbols = demod(i, Data, Params, Rcc);

    % find constellation
    softBits = constellation(symbols, Params);

    % decoding and descrambling
    cvcdus = decode(softBits, Viterbi, Descrambler, Params);
    pause(0.5);
end


% 
% 
% 
% 
% 
% % mcu extraction
% [mcus, qualityFactors, apids] = extraction(cvcdus);
% 
% % jpeg decoding
% Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params);