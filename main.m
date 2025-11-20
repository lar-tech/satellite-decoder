close all; clear; clc;
tic 

% get config
[Data, Params, Rcc, Viterbi, Descrambler, ReedSolomon, Huffman, DCT] = getconfig(); 

% numberBlocks = round(Data.fileSize / Data.blockSize);
% Data.blockSize = int64(Data.fileSize / numberBlocks);
% 
% softBitsAll = [];
% for i = 1:Data.blockSize+1:Data.fileSize
%     % demodulate qpsk
%     symbols = demod(i, Data, Params, Rcc);
% 
%     % find constellation
%     softBits = constellation(i, symbols, Params);
%     softBitsAll = [softBitsAll; softBits];
%     % pause(0.1)
% end
% 19759104
% load("data/softbits.mat");

% decoding and descrambling
% cvcdus = decode(softBitsAll, Viterbi, Descrambler, Params);

load("data/cvcdus.mat")

% mcu extraction
[mcus, qualityFactors, apids] = extraction(cvcdus);

% % jpeg decoding
% Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params);

toc