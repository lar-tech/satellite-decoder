clear; close all; clc;

%% parameter
file = "data/input.wav";   % raw IQ-samples
M = 4;                     % mumber of symbols
Rs = 72e3;                 % symbolrate
rolloff = 0.35;            % rrc roll-off-factor
spanSym = 10;              % rrc window length
targetSps = 4;             % target samples per symbol
targetFs = targetSps * Rs; % targer sampling frequency
minData = 500;               % min position of samples
maxData = 120000;          % max position of samples

%% demodulate qpsk
[y_carr, fs_rs] = demod(file, minData, maxData, rolloff, spanSym, targetSps, targetFs);

%% sync data
% constellation rotation
constellations = {
    [3 2 1 0]... % Imag-inverted
    [1 0 3 2]... % Re-inverted
    [0 3 2 1]... % (I, Q) -> (Q, I)
    [2 1 0 3]... % (I, Q) -> (-Q, -I)
};

% viterbi-decoder
trellis = poly2trellis(7, [117 155]);
vDec = comm.ViterbiDecoder( ...
    'TrellisStructure', trellis, ...
    'InputFormat', 'Hard'...
);

for k = 1:4
    % qpsk demodulation
    symbols = pskdemod(y_carr, M, pi/4, constellations{k});
    bitsPerSym = log2(M);
    bits = de2bi(symbols, bitsPerSym, 'left-msb');
    bitStream = zeros(length(bits),1);
    for i=1:2:length(bitStream)
        disp(bits(1,i))
        bitStream(i) = bits(1,i);
        bitStream(i+1) = bits(2,i);
    end


    % % viterbi-decoding
    % decBits = vDec(bits);
    % 
    % % frame-synchronization
    % syncHex = '1ACFFC1D';
    % syncBytes = sscanf(syncHex, '%2x').';
    % syncBits = de2bi(syncBytes, 8, 'left-msb');
    % syncBits = reshape(syncBits.', 1, []);
    % 
    % % cross-correlation
    % [corr,lags] = xcorr(decBits, syncBits);
    % 
    % figure(k);
    % plot(corr);

end
