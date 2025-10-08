clear; close all; clc;

%% parameter
% file
Data.filePath = "data/input.wav";   % raw IQ-samples
Data.minDataIdx = 1;                % min position of samples
Data.maxDataIdx = 500000;           % max position of samples

% general
Params.plotting = false;            
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
Viterbi.codeGenPoly = [117 155];    % Code generator polynomial of encoder
Viterbi.tblen = 32;                 % Traceback depth of Viterbi decoder
Viterbi.softInputWordLength = 8;    % soft-input-word-length

%% demodulate qpsk
[symbols, fsResampled] = demod(Data, Params, Rcc);

%% sync data to frames
[frames, constellation] = sync(symbols, Params, Viterbi);

% % frame-synchronization-word
% syncHex = '1ACFFC1D';
% syncBytes = sscanf(syncHex, '%2x').';
% syncBits = de2bi(syncBytes, 8, 'left-msb');
% syncBits = reshape(syncBits.', 1, []);
% syncBits = 2*double(syncBits)-1;
% 
% % viterbi-decoder
% trellis = poly2trellis(Viterbi.constLen, Viterbi.codeGenPoly);
% vDec = comm.ViterbiDecoder( ...
%         'TrellisStructure', trellis, ...
%         'InputFormat', 'Soft',...
%         'TracebackDepth', Viterbi.tblen...
%         );
% 
% decBitsSoft = vDec(softBits);