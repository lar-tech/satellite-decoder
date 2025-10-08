function symbols = sync(symbols, Sync, Params, Viterbi)
    
    % tests different constellations 
    if Sync.testConstellations == true
        % sync word before using viterbi
        syncHex = 'FCA2B63DB00D9794';
        syncBytes = sscanf(syncHex, '%2x').';
        syncBits = de2bi(syncBytes, 8, 'left-msb');
        syncBits = reshape(syncBits.', 1, []);
        syncBits = 2*double(syncBits)-1;

        % constellation rotation and symmetry
        for i=1:length(Sync.constellations)

            % qpsk demodulation hard-decoding
            hardBits = pskdemod( ...
                        symbols, ...
                        Params.M, ...
                        pi/4, ...
                        Sync.constellations{i}...
                        ); 
            hardBits = de2bi(hardBits, 2, 'left-msb');
            hardBits = reshape(hardBits.', [], 1);
            
            % cross-correlation
            [corr,~] = xcorr(hardBits, syncBits);
            
            figure(i);
            plot(corr);
            xlabel("Sample");
            ylabel("Amplitude")
            title(sprintf("Crosscorrelation of FCA2B63DB00D9794 and %s", mat2str(Sync.constellations{i})));
        end
    end
end