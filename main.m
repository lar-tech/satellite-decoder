clear; close all; clc;

%% parameter
% file
Data.filePath = "data/input.wav";   % raw IQ-samples
Data.minDataIdx = 1;                % min position of samples
Data.maxDataIdx = 500000;           % max position of samples

% general
Params.plotting = true;            
Params.minClip = -0.01;             % min value for clipping
Params.maxClip = 0.01;              % max value for clippling
Params.M = 4;                       % mumber of symbols
Params.symbolRate = 72e3;           % symbolrate
Params.targetSps = 4;               % target samples per symbol
Params.constellations = {
                        [0 1 3 2], ...      % default
                        [1 3 2 0], ...      % 90°
                        [3 2 0 1], ...      % 180°
                        [2 0 1 3], ...      % 270°
                        [2 3 1 0], ...      % Imag-inverted
                        [1 0 2 3], ...      % Re-inverted
                        [0 2 3 1], ...      % (I, Q) -> (Q, I)
                        [3 1 0 2], ...      % (I, Q) -> (-Q, -I)
                        };

% rcc
Rcc.rollOff = 0.35;                 % roll-off-factor
Rcc.spanSym = 10;                   % window length

% viterbi
Viterbi.codeRate = 1/2;             % Code rate of convolutional encoder
Viterbi.constLen = 7;               % Constraint length of encoder
Viterbi.codeGenPoly = [171 133];    % Code generator polynomial of encoder
Viterbi.tblen = 30;                 % Traceback depth of Viterbi decoder
Viterbi.softInputWordLength = 8;    % soft-input-word-length

% descrambler
Descrambler.base = 2;                           % binary base
% Descrambler.polynom = '1+x^-3+x^-5+x^-7+x^-8';  % polynom
Descrambler.polynom = '1+x^-14+x^-17';  % polynom
Descrambler.init = [1 1 0 0 0 1 1 1 0 0 0 1 1 1 0 0 0];                   % initial conditions

% reed-solomon
ReedSolomon.interleavingDepth = 4;
ReedSolomon.codeWordLength = 255;                       % n = 2^(bitsPerSymbol)-1
ReedSolomon.messageLength = 223;                        % k = n - 2E
ReedSolomon.primitivePolynomial = [1 1 0 0 0 0 1 1 1];  % x^8 + x^7 + x^2 + x + 1

%% demodulate qpsk
[symbols, fsResampled] = demod(Data, Params, Rcc);

%% find constellation
[softBits, constellation] = constellation(symbols, Params);
% 
%% decoding and descrambling
[cadus, cvcdus] = decode(softBits, Viterbi, Descrambler, Params);

%% reed-solomon correction
% vcdus = correction(cvcdus, ReedSolomon, Params);

% bit -> byte
for i = 1:numel(cadus)
    cadu = reshape(cadus{i}, 8, []).';
    cadus{i} = bi2de(cadu, 'left-msb');
    cvcdu = reshape(cvcdus{i}, 8, []).';
    cvcdus{i} = bi2de(cvcdu, 'left-msb');
end

% de-interleaving
deinterleavedBlocks = cell(1, numel(cvcdus));
for i = 1:numel(cvcdus)
    cvcdu = cvcdus{i};
    rsBlock = zeros(ReedSolomon.interleavingDepth, ReedSolomon.codeWordLength, 'uint8');
    for j = 1:ReedSolomon.interleavingDepth
        rsBlock(j, :) = cvcdu(j:ReedSolomon.interleavingDepth:end);
    end
    deinterleavedBlocks{i} = rsBlock;
end

% reed-solomon decoder
generatorPolynomial = rsgenpoly(ReedSolomon.codeWordLength, ReedSolomon.messageLength, bi2de(ReedSolomon.primitivePolynomial, 'left-msb'));
rsDec = comm.RSDecoder( ...
            'CodewordLength', ReedSolomon.codeWordLength, ...    
            'MessageLength', ReedSolomon.messageLength, ...     
            'GeneratorPolynomialSource', 'Property', ...
            'GeneratorPolynomial', generatorPolynomial, ...
            'PrimitivePolynomialSource', 'Property', ...
            'PrimitivePolynomial', ReedSolomon.primitivePolynomial ...
        );
correctedBlocks = cell(1, numel(deinterleavedBlocks));
numErrors = cell(1, numel(deinterleavedBlocks));
for i = 1:numel(deinterleavedBlocks)
    rsBlock = deinterleavedBlocks{i};
    correctedBlock = zeros(4, ReedSolomon.messageLength, 'uint8');
    numError = zeros(4,1);
    for j = 1:4
        [correctedBlock(j,:), numError(j)] = rsDec(rsBlock(j,:).');
        fprintf('Block %d: %d Bytefehler korrigiert\n', j, numError(j));
    end
    correctedBlocks{i} = correctedBlock;
    numErrors{i} = numError;
end

% re-interleaving
reinterleavedBlocks = cell(1, numel(correctedBlocks));
for i = 1:numel(correctedBlocks)
    correctedBlock = correctedBlocks{i};
    reinterleavedBlock = zeros(1, ReedSolomon.interleavingDepth*ReedSolomon.messageLength, 'uint8');
    idx = 1;
    for col = 1:ReedSolomon.messageLength
        for row = 1:ReedSolomon.interleavingDepth
            reinterleavedBlock(idx) = correctedBlock(row, col);
            idx = idx + 1;
        end
    end
    bits = de2bi(reinterleavedBlock, 8, 'left-msb');
    bits = reshape(bits.', 1, []);
    reinterleavedBlocks{i} = logical(bits(:));
end
