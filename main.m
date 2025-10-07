clear; close all; clc;

%% parameter
% file
Data.filePath = "data/input.wav";   % raw IQ-samples
Data.minDataIdx = 500000;              % min position of samples
Data.maxDataIdx = 600000;         % max position of samples

% general
Params.minClip = -0.01;             % min value for clipping
Params.maxClip = 0.01;              % max value for clippling
Params.M = 4;                       % mumber of symbols
Params.symbolRate = 72e3;           % symbolrate
Params.targetSps = 4;               % target samples per symbol

% rcc
Rcc.rollOff = 0.35;                 % roll-off-factor
Rcc.spanSym = 10;                   % window length

% viterbi
Viterbi.codeRate = 1/2;             % Code rate of convolutional encoder
Viterbi.constLen = 7;               % Constraint length of encoder
Viterbi.codeGenPoly = [117 155];    % Code generator polynomial of encoder
Viterbi.tblen = 32;                 % Traceback depth of Viterbi decoder
Viterbi.softInputWordLength = 8;    % soft-input-word-length

%% demodulate qpsk
[symbols, fsResampled] = demod(Data, Params, Rcc);

%% sync data
% constellation rotation and symmetry
constellations = {
    [0 1 3 2], ...      % default
    [1 3 2 0], ...      % 90°
    [3 2 0 1], ...      % 180°
    [2 0 1 3], ...      % 270°
    [2 3 1 0], ...      % Imag-inverted
    [1 0 2 3], ...      % Re-inverted
    [0 2 3 1], ...      % (I, Q) -> (Q, I)
    [3 1 0 2], ...      % (I, Q) -> (-Q, -I)
};

% frame-synchronization-word
syncHex = '1ACFFC1D';
syncBytes = sscanf(syncHex, '%2x').';
syncBits = de2bi(syncBytes, 8, 'left-msb');
syncBits = reshape(syncBits.', 1, []);

% viterbi-decoder
trellis = poly2trellis(Viterbi.constLen, Viterbi.codeGenPoly);

%% soft decoding
vDecSoft = comm.ViterbiDecoder( ...
        'TrellisStructure', trellis, ...
        'InputFormat', 'Soft',...
        'TracebackDepth', Viterbi.tblen...
        );

for i=1:numel(constellations)
    % qpsk demodulation
    softBits = pskdemod( ...
                symbols, ...
                Params.M, ...
                pi/4, ...
                constellations{i}, ...
                OutputType="llr" ...
                ); % PlotConstellation=true
    softBitsScaled = softBits * 8;
    
    % viterbi-decoder
    reset(vDecSoft);
    decBitsSoft = vDecSoft(softBitsScaled);
    
    % cross-correlation
    [corr,lags] = xcorr(decBitsSoft, syncBits);
    
    figure(i);
    plot(corr);
end

%% hard decoding
vDecHard = comm.ViterbiDecoder( ...
        'TrellisStructure', trellis, ...
        'InputFormat', 'Hard',...
        'TracebackDepth', Viterbi.tblen...
        );
for i=1:numel(constellations)
    % qpsk demodulation hard
    hardBits = pskdemod( ...
                symbols, ...
                Params.M, ...
                pi/4, ...
                constellations{i}...
                ); % PlotConstellation=true
    hardBits = de2bi(hardBits, 2, 'left-msb');
    hardBits = reshape(hardBits.', [], 1);

    % viterbi-decoder
    reset(vDecHard);
    decBitsHard = vDecHard(hardBits);

    % cross-correlation
    [corr,lags] = xcorr(decBitsHard, syncBits);

    figure(8+i);
    plot(corr);
end