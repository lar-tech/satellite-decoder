close all; clear; clc;
tic 

% get configurations
[Data, Params, Rcc, Viterbi, Descrambler, ReedSolomon, Huffman, DCT] = getconfig();

% pre-evaluation
preeval(Data, Params);

% demodulation
symbols = demod(Data, Params, Rcc);

% constellation
softBits = constellation(0, symbols, Params);

% decoding and descrambling
cvcdus = decode(softBits, Viterbi, Descrambler, Params);

% mcu extraction
[mcus, qualityFactors, apids] = extraction(cvcdus, Params);

% % jpeg decoding
Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT);

toc