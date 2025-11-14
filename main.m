close all; clear; clc;

%% get config
[Data, Params, Rcc, Viterbi, Descrambler, ReedSolomon, Huffman, DCT] = getConfig; 

%% demodulate qpsk
symbols = demod(Data, Params, Rcc);

%% find constellation
softBits = constellation(symbols, Params);

%% decoding and descrambling
cvcdus = decode(softBits, Viterbi, Descrambler, Params);

%% mcu extraction
[mcus, qualityFactors, apids] = extraction(cvcdus);

%% jpeg decoding
Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params.plotting);