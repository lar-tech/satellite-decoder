close all; clear; clc; addpath("src")
tic

% get configurations
[Data, Params, Rcc, Viterbi, Descrambler, ReedSolomon, Huffman, DCT] = getconfig();

% pre-evaluation
qualitycheck(Data, Params);

% demodulation
symbols = demod(Data, Params, Rcc);

% constellation
softBits = constellation(0, symbols, Params);

% decoding and descrambling
cvcdus = decode(softBits, Viterbi, Descrambler, Params); 

% reed-solomon correction
[cvcdus, rsErrors] = reedsolomon(cvcdus, ReedSolomon, Params);

% mcu extraction
[mcus, qualityFactors, apids, Meta] = extraction(cvcdus, Params);

% jpeg decoding
Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params, Meta);

toc