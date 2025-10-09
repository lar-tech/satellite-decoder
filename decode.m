function cadus = decode(softBits, Viterbi, Descrambler, Params)
    
    % viterbi-decoder
    trellis = poly2trellis(Viterbi.constLen, Viterbi.codeGenPoly);
    vDec = comm.ViterbiDecoder( ...
            'TrellisStructure', trellis, ...
            'InputFormat', 'Soft',...
            'TracebackDepth', Viterbi.tblen,...
            'TerminationMethod','Continuous'...
            );
    softBitsScaled = -softBits * 10;
    decodedBits = vDec(softBitsScaled);
    
    % sync word
    syncAsm = '1ACFFC1D';
    syncAsmBytes = sscanf(syncAsm, '%2x').';
    syncAsmBits = de2bi(syncAsmBytes, 8, 'left-msb');
    syncAsmBits = reshape(syncAsmBits.', [], 1);
    syncAsmBits = 2*double(syncAsmBits)-1;
    
    [corr, lags] = xcorr(decodedBits, syncAsmBits);
    [pks,locs] = findpeaks(corr, 'MinPeakDistance',7750, 'Threshold',10);

    if Params.plotting
        figure()
        plot(lags, corr); hold on;
        plot(lags(locs), pks, 'rx');
        hold off;
        xlabel('Samples');
        ylabel('Cross-correlation amplitude');
        title('Cross-correlation of 1ACFFC1D and decoded Softbits');
        grid on;
    end
    
    % remove sync word for descrambling
    payloads = cell(1, numel(locs));
    for k = 1:numel(locs)
        start_idx = lags(locs(k))+length(syncAsmBits)+1;
        stop_idx  = start_idx + 8160-1;
        if start_idx > 0 && stop_idx <= numel(decodedBits)
            payloads{k} = decodedBits(start_idx:stop_idx);
        else
            payloads{k} = [];
        end
    end
    validFrames = ~cellfun(@isempty, payloads);
    payloads = payloads(validFrames);
    
    % descrambler
    descrambler = comm.Descrambler( ...
                            'CalculationBase', Descrambler.base, ...
                            'Polynomial', Descrambler.polynom, ...
                            'InitialConditions', Descrambler.init ...
                            );
    cadus = cell(size(payloads));
    for k = 1:numel(payloads)
        payloadBits = logical(payloads{k});
        descrambledPayload = descrambler(payloadBits);
        syncWord = decodedBits(lags(locs(k)):lags(locs(k))+length(syncAsmBits)-1);
        cadu = vertcat(syncWord, descrambledPayload);
        cadu = reshape(cadu, 8, []).';
        cadus{k} = bi2de(cadu, 'left-msb');
        reset(descrambler);
    end
end