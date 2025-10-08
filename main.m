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
Viterbi.codeGenPoly = [171 133];    % Code generator polynomial of encoder
Viterbi.tblen = 30;                 % Traceback depth of Viterbi decoder
Viterbi.softInputWordLength = 8;    % soft-input-word-length

% descrambler
Descrambler.base = 2;                   % binary base
Descrambler.polynom = '1+x^-14+x^-15';  % polynom
Descrambler.init = ones(1,15);          % initial conditions

%% demodulate qpsk
[symbols, fsResampled] = demod(Data, Params, Rcc);

%% sync data to frames
% [frames, hardBits, constellation] = sync(symbols, Params);

% sync word
syncAsm = 'FCA2B63DB00D9794';
syncAsmBytes = sscanf(syncAsm, '%2x').';
syncAsmBits = de2bi(syncAsmBytes, 8, 'left-msb');
syncAsmBits = reshape(syncAsmBits.', 1, []);
syncAsmBits = 2*double(syncAsmBits)-1;

for i=1:length(Params.constellations)
    % qpsk demodulation hard-decoding
    % softBits = pskdemod( ...
    %             symbols, ...
    %             Params.M, ...
    %             pi/4, ...
    %             Params.constellations{i}, ...
    %             OutputType="llr" ...
    %             );
    hardBits = pskdemod( ...
                symbols, ...
                Params.M, ...
                pi/4, ...
                Params.constellations{i} ...
                );
    hardBits = de2bi(hardBits, 2, 'left-msb');
    hardBits = reshape(hardBits.', [], 1);

    % cross-correlation
    [corr,lags] = xcorr(hardBits, syncAsmBits);

    % find peaks and calculate widths
    [pks,locs] = findpeaks(corr, 'MinPeakProminence',35); %'MinPeakDistance',15500, 'Threshold',35);
    width = mean(diff(locs))/16;
    if width >= 1020 || width <= 1030 && width==1024
        correctConstellation = Params.constellations{i};
        break
    end
end
asmLen = 64;
frameLen = 16384;

frames = cell(1, numel(locs));
for k = 1:numel(locs)
    start_idx = lags(locs(k));
    stop_idx  = start_idx + frameLen - 1;
    if start_idx > 0 && stop_idx <= numel(hardBits)
        frames{k} = hardBits(start_idx:stop_idx);
    else
        frames{k} = [];
    end
end
validFrames = ~cellfun(@isempty, frames);
frames = frames(validFrames);

frame = frames{1};
% [corr, lags] = xcorr(frame, syncAsmBits);

% viterbi-decoder
trellis = poly2trellis(Viterbi.constLen, Viterbi.codeGenPoly);
vDec = comm.ViterbiDecoder( ...
        'TrellisStructure', trellis, ...
        'InputFormat', 'Hard',...
        'TracebackDepth', Viterbi.tblen,...
        'TerminationMethod','Continuous'...
        );
x = ones(100,1);
code = convenc(x,trellis);
decodedBits = vDec(code);


% syncAsm = '1ACFFC1D';
% syncAsmBytes = sscanf(syncAsm, '%2x').';
% syncAsmBits = de2bi(syncAsmBytes, 8, 'left-msb');
% syncAsmBits = reshape(syncAsmBits.', 1, []);
% 
% decodedBits = vDec(frame(:));
% [corr, lags] = xcorr(decodedout, syncAsmBits);
% plot(lags, corr);

% descrambler = comm.Descrambler(Descrambler.base, ...
%                         Descrambler.polynom, ...
%                         Descrambler.init ...
%                         );
% 
% descrambledBits = cell(size(decodedBits));
% for k = 1:numel(decodedBits)
%     decodedBit = logical(decodedBits{k});
%     descrambledBits{k} = descrambler(decodedBit(:));
%     reset(descrambler);
% end