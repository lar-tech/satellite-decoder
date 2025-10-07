clear; close all; clc;

%% parameter
file = "data/input.wav";   % raw IQ-samples
M = 4;                     % mumber of symbols
Rs = 72e3;                 % symbolrate
minData = 500;             % min position of samples
maxData = 120000;          % max position of samples
minClip = -0.01;
maxClip = 0.01;

% rcc
rolloff = 0.35;            % rrc roll-off-factor
spanSym = 10;              % rrc window length
targetSps = 4;             % target samples per symbol
targetFs = targetSps * Rs; % targer sampling frequency

% Viterbi
codeRate = 1/2;            % Code rate of convolutional encoder
constLen = 7;              % Constraint length of encoder
codeGenPoly = [117 155];   % Code generator polynomial of encoder
tblen = 32;                % Traceback depth of Viterbi decoder
softInputWordLength = 8;   % soft-input-word-length

%% demodulate qpsk
[y_carr, fs_rs] = demod(file, minData, maxData, minClip, maxClip, rolloff, spanSym, targetSps, targetFs);

%% sync data
% constellation rotation
constellations = {
    % [0 1 3 2] ... % default case
    [2 3 1 0]... % Imag-inverted
    [1 0 2 3]... % Re-inverted
    [0 2 3 1]... % (I, Q) -> (Q, I)
    [3 1 0 2]... % (I, Q) -> (-Q, -I)
};

% qpsk soft demodulation
symbols = pskdemod( ...
    y_carr, ...
    M, ...
    pi/4, ...
    constellations{4}, ...
    OutputType="llr"); % PlotConstellation=true

symbols = symbols * 8;

% viterbi-decoder
trellis = poly2trellis(constLen, codeGenPoly);
vDec = comm.ViterbiDecoder( ...
    'TrellisStructure', trellis, ...
    'InputFormat', 'Soft',...
    'TracebackDepth', tblen...
);

decBits = vDec(symbols);

% frame-synchronization
syncHex = '1ACFFC1D';
syncBytes = sscanf(syncHex, '%2x').';
syncBits = de2bi(syncBytes, 8, 'left-msb');
syncBits = reshape(syncBits.', 1, []);

% cross-correlation
[corr,lags] = xcorr(decBits, fliplr(syncBits));

figure(1);
plot(corr);


% for k = 1:4
    % % qpsk soft demodulation
    % symbols = pskdemod( ...
    %     y_carr, ...
    %     M, ...
    %     pi/4, ...
    %     constellations{k}, ...
    %     OutputType="llr",...
    %     PlotConstellation=true ...
    % );
    % 
    % % viterbi-decoding
    % reset(vDec);
    % decBits = vDec(symbols);
    % 
    % % frame-synchronization
    % syncHex = '1ACFFC1D';
    % syncBytes = sscanf(syncHex, '%2x').';
    % syncBits = de2bi(syncBytes, 8, 'left-msb');
    % syncBits = reshape(syncBits.', 1, []);
    % 
    % % cross-correlation
    % [corr,lags] = xcorr(decBits, fliplr(syncBits));
    % 
    % figure(k);
    % plot(corr);
% end
