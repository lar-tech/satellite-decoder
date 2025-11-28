function symbols = demod(Data, Params, Rcc)
    % create objects
    rrcRx = comm.RaisedCosineReceiveFilter( ...
                'RolloffFactor', Rcc.rollOff, ...
                'FilterSpanInSymbols', Rcc.spanSym, ...
                'InputSamplesPerSymbol', Params.targetSps, ...
                'DecimationFactor', 1 ...
                );
    cfo = comm.CoarseFrequencyCompensator(Modulation='qpsk', SampleRate=Data.fs);
    symSync = comm.SymbolSynchronizer( ...
                'TimingErrorDetector', 'Zero-Crossing (decision-directed)', ...
                'SamplesPerSymbol', Params.targetSps ...
                );
    carrierSync = comm.CarrierSynchronizer( ...
                    'Modulation','QPSK', ...    
                    'SamplesPerSymbol',1 ...
                    );
    
    % load data
    I = single(Data.raw(:,1));
    Q = single(Data.raw(:,2));
    I = clip(I, Params.minClip, Params.maxClip);
    Q = clip(Q, Params.minClip, Params.maxClip);
    I = I / max(abs(I));
    Q = Q / max(abs(Q));
    x = (I + 1j*Q);
    
    % fir-resampling     
    xResampled = resample(x, Params.p, Params.q);
    
    % rrc-matched-filter
    yFilteredAll = rrcRx(xResampled);
    
    i = 1;
    symbols = [];
    while i+Params.blockSize <= numel(yFilteredAll)
        if i+Params.blockSize <= numel(yFilteredAll)
            yFiltered = yFilteredAll(i:i+Params.blockSize-1);
        else
            % if last block exceeds filesize 
            yFiltered = yFilteredAll(i:end);
        end
    
        % cfo-compensation
        yCfo = cfo(yFiltered);
    
        % symbol-timing-recovery
        ySync = symSync(yCfo);
    
        % carrier-recovery
        symBlock = carrierSync(ySync);
    
        symbols = [symbols; symBlock];

        i = i + Params.blockSize;
    
        % % plotting
        % if Params.plotting
        %     figure(1);
        %     plot(real(symBlock), imag(symBlock), marker='.', LineStyle='none')
        %     axis equal;
        %     axis([-2.5 2.5 -2.5 2.5]);
        %     grid on;
        %     xlabel('I-Component');
        %     ylabel('Q-Component');
        %     title('Demodulated QPSK-Symbols');
        %     pause(0.01);
        % end
    end
end