function [cadus, cvcdus] = decode(softBits, Viterbi, Descrambler, Params)
    
    % viterbi-decoder
    trellis = poly2trellis(Viterbi.constLen, Viterbi.codeGenPoly);
    vDec = comm.ViterbiDecoder( ...
            'TrellisStructure', trellis, ...
            'InputFormat', 'Soft',...
            'TracebackDepth', Viterbi.tblen,...
            'TerminationMethod','Continuous'...
            );
    softBitsScaled = softBits * 10;
    decodedBits = vDec(softBitsScaled);
    decodedBits = 2*double(decodedBits)-1;
    
    % sync word
    syncAsm = '1ACFFC1D';
    syncAsmBytes = sscanf(syncAsm, '%2x').';
    syncAsmBits = de2bi(syncAsmBytes, 8, 'left-msb');
    syncAsmBits = reshape(syncAsmBits.', [], 1);
    syncAsmBits = 2*double(syncAsmBits)-1;
    
    [corr, lags] = xcorr(decodedBits, syncAsmBits);
    [pks,locs] = findpeaks(abs(corr), 'MinPeakDistance',7750, 'Threshold',10);
    
    % invert Bits if correlation is negative
    if corr(locs) < 0
        corr = -corr;
        decodedBits = -decodedBits;
        decodedBits = double(decodedBits+1)/2;
    end

    if Params.plotting
        figure()
        plot(lags, corr); hold on;
        plot(lags(locs), pks, 'rx');
        hold off;
        xlabel('Samples');
        ylabel('Cross-correlation');
        title('Cross-correlation of 1ACFFC1D and decoded Softbits');
        grid on;
    end

    % remove sync word for descrambling
    payloads = cell(1, numel(locs));
    for i = 1:numel(locs)
        start_idx = lags(locs(i))+length(syncAsmBits)+1;
        stop_idx  = start_idx + 8160-1;
        if start_idx > 0 && stop_idx <= numel(decodedBits)
            payloads{i} = decodedBits(start_idx:stop_idx);
        else
            payloads{i} = [];
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
    cvcdus = cell(size(payloads));
    for i = 1:numel(payloads)
        payloadBits = logical(payloads{i});
        descrambledPayload = descrambler(payloadBits);
        cvcdus{i} = descrambledPayload;
        syncWord = decodedBits(lags(locs(i)):lags(locs(i))+length(syncAsmBits)-1);
        cadus{i} = vertcat(syncWord, descrambledPayload);
        reset(descrambler);
    end
end