close all; clear; clc;
tic 

% get config
[Data, Params, Rcc, Viterbi, Descrambler, ReedSolomon, Huffman, DCT] = getconfig(); 

% demodulation
symbols = demod(Data, Params, Rcc);

% constellation
softBits = constellation(0, symbols, Params);

% decoding and descrambling
[cvcdus, payloads, decodedBits] = decode(softBits, Viterbi, Descrambler, Params);

% mcu extraction
[mcus, qualityFactors, apids] = extraction(cvcdus, Params);

% % jpeg decoding
% Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params);
% figure;
% imshow(Images.jpeg64);
% figure;
% imshow(Images.jpeg65);
% figure;
% imshow(Images.jpeg68);

toc