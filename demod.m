function [y_carr, fs_rs] = demod(file, minData, maxData, rolloff, spanSym, targetSps, targetFs)
    % load data
    [rawData, fs] = audioread(file);
    I = single(rawData(:,1));
    Q = single(rawData(:,2));
    x = (I + 1j*Q);
    x = x ./ max(abs(x));
    x = x(minData:maxData);
    
    % resampling
    [p, q] = rat(targetFs/fs);         
    x_rs = resample(x, p, q);           
    fs_rs = fs * p / q;                
    
    % rrc-matched-filter
    rrcRx = comm.RaisedCosineReceiveFilter( ...
        'RolloffFactor', rolloff, ...
        'FilterSpanInSymbols', spanSym, ...
        'InputSamplesPerSymbol', targetSps, ...
        'DecimationFactor', 1);
    y_filt = rrcRx(x_rs);
    
    % cfo-Estimation
    y_quartic = y_filt .^4;
    Nfft = length(y_quartic);
    psd = abs(fftshift(fft(y_quartic, Nfft)));
    f = linspace(-fs/2, fs/2, Nfft);
    [~, idx] = max(psd);
    max_freq = f(idx);
    fo_est = max_freq / 4.0;
    n = (0:length(y_filt)-1).';
    y_cfo = y_filt .* exp(-1j*2*pi*fo_est*n/fs);
    
    % symbol-timing-recovery
    symSync = comm.SymbolSynchronizer( ...
        'TimingErrorDetector', 'Zero-Crossing (decision-directed)', ...
        'SamplesPerSymbol', targetSps);
    y_sym = symSync(y_cfo);
    
    % carrier-recovery
    carrierSync = comm.CarrierSynchronizer( ...
        'Modulation','QPSK', ...    
        'SamplesPerSymbol',1);
    y_carr = carrierSync(y_sym);

end