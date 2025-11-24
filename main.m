close all; clear; clc;
tic 

% get config
[Data, Params, Rcc, Viterbi, Descrambler, ReedSolomon, Huffman, DCT] = getconfig(); 

softBitsAll = [];
counter = 1;
for i = 1:Data.blockSize+1:Data.fileSize
    % demodulate qpsk
    symbols = demod(i, Data, Params, Rcc);

    % find constellation
    softBits = constellation(symbols, Params);
    softBitsAll = [softBitsAll; softBits];

    if counter == 1
        break
    end
end

% % decoding and descrambling
% [cvcdus, payloads, decodedBits] = decode(softBitsAll, Viterbi, Descrambler, Params);
% 
% % mcu extraction
% [mcus, qualityFactors, apids] = extraction(cvcdus);
% 
% % % jpeg decoding
% Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params);

toc