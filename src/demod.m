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
    I = I / max(max(abs(I)), eps('single'));
    Q = Q / max(max(abs(Q)), eps('single'));
    x = (I + 1j*Q);
    
    % fir-resampling     
    xResampled = resample(x, Params.p, Params.q);
    
    % rrc-matched-filter
    yFilteredAll = rrcRx(xResampled);
    
    i = 1;
    symbols = [];

    hPlot = [];
    if Params.plotting
        figure; clf;
        hPlot = plot(nan, nan, '.', 'MarkerSize', 8);
        axis equal;
        axis([-2.5 2.5 -2.5 2.5]);
        grid on;
        xlabel('I');
        ylabel('Q');
        title('QPSK Constellation');
    end
    

    while i <= numel(yFilteredAll)
        if i+Params.blockSize-1 <= numel(yFilteredAll)
            yFiltered = yFilteredAll(i:i+Params.blockSize-1);
        else
            % if last block exceeds filesize 
            yFiltered = yFilteredAll(i:end);
        end
    
        % reinitialize fixed-size objects for the last partial block
        if numel(yFiltered) < Params.blockSize
            if numel(yFiltered) < Params.targetSps
                break
            end
            release(cfo);
            release(symSync);
        end

        % cfo-compensation
        yCfo = cfo(yFiltered);
    
        % symbol-timing-recovery
        ySync = symSync(yCfo);
    
        % carrier-recovery
        symBlock = carrierSync(ySync);
    
        symbols = [symbols; symBlock];

        i = i + Params.blockSize;
    
        % plotting
        if Params.plotting
            set(hPlot, 'XData', real(symBlock), 'YData', imag(symBlock));
            drawnow limitrate;
        end
    end
    if Params.plotting && Params.export
        exportgraphics(gcf, "data/plots/demodulated.pdf")
    end
end