clear; close all; clc;
% Parameter
M=4;
file = "data/input.wav";
Rs   = 72e3;           
rolloff = 0.35;
spanSym = 10;          
targetSps = 4;         
targetFs  = targetSps * Rs;

% load data
[rawData, fs] = audioread(file);
I = single(rawData(:,1));
Q = single(rawData(:,2));
x = (I + 1j*Q);
x = x ./ max(abs(x));
x = x(1:100000);

% Resampling
[p, q] = rat(targetFs/fs);         
x_rs = resample(x, p, q);           
fs_rs = fs * p / q;                
sps = fs_rs / Rs;                   

% RRC-Matched-Filter
rrcRx = comm.RaisedCosineReceiveFilter( ...
    'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', spanSym, ...
    'InputSamplesPerSymbol', targetSps, ...
    'DecimationFactor', 1);
y_filt = rrcRx(x_rs);

% CFO-Estimation
y_quartic = y_filt .^4;
Nfft = length(y_quartic);
psd = abs(fftshift(fft(y_quartic, Nfft)));
f = linspace(-fs/2, fs/2, Nfft);
[~, idx] = max(psd);
max_freq = f(idx);
fo_est = max_freq / 4.0;
n = (0:length(y_filt)-1).';
y_cfo = y_filt .* exp(-1j*2*pi*fo_est*n/fs);

% Symbol-Timing-Recovery
symSync = comm.SymbolSynchronizer( ...
    'TimingErrorDetector', 'Zero-Crossing (decision-directed)', ...
    'SamplesPerSymbol', targetSps);
y_sym = symSync(y_cfo);

% Carrier-Recovery
carrierSync = comm.CarrierSynchronizer( ...
    'Modulation','QPSK', ...    
    'SamplesPerSymbol',1);
y_carr = carrierSync(y_sym);

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
