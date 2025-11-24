clc; clear; close all;

% get config
[Data, Params, Rcc, Viterbi, Descrambler, ReedSolomon, Huffman, DCT] = getconfig(); 
load("data/mcus.mat");

Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params);
figure;
imshow(Images.jpeg64);
figure;
imshow(Images.jpeg65);
figure;
imshow(Images.jpeg68);