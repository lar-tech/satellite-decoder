clear; close all; clc;

% parameter
file = "data/input.wav";   % raw IQ-samples
M = 4;                     % mumber of symbols
Rs = 72e3;                 % symbolrate
rolloff = 0.35;            % rrc roll-off-factor
spanSym = 10;              % rrc window length
targetSps = 4;             % target samples per symbol
targetFs = targetSps * Rs; % targer sampling frequency
maxData = 100000;          % max numer of samples

% demodulate qpsk
[y_carr, fs_rs] = demod(file, maxData, rolloff, spanSym, targetSps, targetFs);

% decode data
% Constellation Rotation
constellations = {
    [3 2 1 0]... % Imag-inverted   
    [1 0 3 2]... % Re-inverted
    [0 3 2 1]... % (I, Q) -> (Q, I)
    [2 1 0 3]... % (I, Q) -> (-Q, -I)
};

% Viterbi-Decoder
viterbidecoder = comm.ViterbiDecoder;

for k = 1:4
    % QPSK demodulation
    symbols = pskdemod(y_carr, M, pi/4, constellations{k});
    bitsPerSym = log2(M);
    bits = de2bi(symbols, bitsPerSym, 'left-msb');
    bits = bits(:);

    % Frame-Synchronization
    syncHex = '1ACFFC1D';
    syncBytes = sscanf(syncHex, '%2x').';
    syncBits = de2bi(syncBytes, 8, 'left-msb');
    syncBits = reshape(syncBits.', 1, []);

    % Cross-Korrelation
    [corr,lags] = xcorr(bits,syncBits);

    figure(k);
    plot(corr);
    ax = gca;
    filename = sprintf('plots/plot_%d.pdf', k);
    exportgraphics(ax, filename);

end

% % Prints
% fprintf("Abtastrate: %d Hz\n", fs);
% fprintf("Datenform: %d x %d\n", size(rawData,1), size(rawData,2));
% fprintf('Syncword gefunden bei Position %d (Korrelation=%.1f)\n', idx, pk);

% Plot
% scatterplot(x)
% scatterplot(y_cfo)
% scatterplot(y_sym)
% scatterplot(y_carr)
% figure;
% plot(corr);
% xlabel('Sample Offset');
% ylabel('Korrelation');
% title('Korrelation mit encodiertem Syncwort 0x1ACFFC1D');
% grid on;
