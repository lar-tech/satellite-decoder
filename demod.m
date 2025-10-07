function [symbols, fsResampled] = demod(Data, Params, Rcc)
    % load data
    [rawData, fs] = audioread(Data.filePath);
    I = single(rawData(:,1));
    Q = single(rawData(:,2));
    I = clip(I,Params.minClip,Params.maxClip);
    Q = clip(Q,Params.minClip,Params.maxClip);
    I = I / max(abs(I));
    Q = Q / max(abs(Q));
    x = (I + 1j*Q);
    x = x(Data.minDataIdx:Data.maxDataIdx);

    % resampling
     targetFs = Params.targetSps * Params.symbolRate; 
    [p, q] = rat(targetFs/fs);         
    xResampled = resample(x, p, q);           
    fsResampled = fs * p / q;                
    
    % rrc-matched-filter
    rrcRx = comm.RaisedCosineReceiveFilter( ...
        'RolloffFactor', Rcc.rollOff, ...
        'FilterSpanInSymbols', Rcc.spanSym, ...
        'InputSamplesPerSymbol', Params.targetSps, ...
        'DecimationFactor', 1);
    yFiltered = rrcRx(xResampled);
    
    % cfo-Estimation
    yQuartic = yFiltered .^4;
    Nfft = length(yQuartic);
    psd = abs(fftshift(fft(yQuartic, Nfft)));
    f = linspace(-fs/2, fs/2, Nfft);
    [~, idx] = max(psd);
    max_freq = f(idx);
    foEst = max_freq / 4.0;
    n = (0:length(yFiltered)-1).';
    yCfo = yFiltered .* exp(-1j*2*pi*foEst*n/fs);
    
    % symbol-timing-recovery
    symSync = comm.SymbolSynchronizer( ...
        'TimingErrorDetector', 'Zero-Crossing (decision-directed)', ...
        'SamplesPerSymbol', Params.targetSps);
    ySync = symSync(yCfo);
    
    % carrier-recovery
    carrierSync = comm.CarrierSynchronizer( ...
        'Modulation','QPSK', ...    
        'SamplesPerSymbol',1);
    symbols = carrierSync(ySync);

end