close all; clear; clc;
tic 

% get config
[Data, Params, Rcc, Viterbi, Descrambler, ReedSolomon, Huffman, DCT] = getconfig(); 

% numberBlocks = round(Data.fileSize / Data.blockSize);
% Data.blockSize = int64(Data.fileSize / numberBlocks);
% symbols = [];
% 
% % for i = 1:Data.blockSize:Data.fileSize
% i = 1;
% softBits = [];
% lastFrames = 0;
% while i < Data.fileSize
%     if (Data.fileSize - i) < 4*16384
%         lastFrames = 1;
%     end
%     % demodulate qpsk
%     symbols = demod(i, Data, Params, Rcc);
% 
%     % find constellation
%     softBitsFramed = constellation(lastFrames, symbols, Params);
%     softBits = [softBits; softBitsFramed];
% 
%     if lastFrames; break; end
%     i = i + numel(softBitsFramed);
% end

load("data/softbits.mat");

% decoding and descrambling
cvcdus = decode(softBits, Viterbi, Descrambler, Params);

% mcu extraction
[mcus, qualityFactors, apids] = extraction(cvcdus);

% % jpeg decoding
% Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params);

toc