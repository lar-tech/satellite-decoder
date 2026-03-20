function cvcdus = decode(softBits, Viterbi, Descrambler, Params)
    % viterbi-decoder
    trellis = poly2trellis(Viterbi.constLen, Viterbi.codeGenPoly);
    vDec = comm.ViterbiDecoder( ...
            'TrellisStructure', trellis, ...
            'InputFormat', 'Soft',...
            'TracebackDepth', Viterbi.tblen...
            );
    softBitsScaled = softBits * 10;
    decodedBits = vDec(softBitsScaled);
    decodedBits = 2*double(decodedBits)-1;
    
    % invert Bits don't know why
    decodedBits = -decodedBits;
    
    % sync word
    syncAsm = '1ACFFC1D';
    syncAsmBytes = sscanf(syncAsm, '%2x').';
    syncAsmBits = de2bi(syncAsmBytes, 8, 'left-msb');
    syncAsmBits = reshape(syncAsmBits.', [], 1);
    syncAsmBits = 2*double(syncAsmBits)-1;
    
    [corr, lags] = xcorr(decodedBits, syncAsmBits);
    [pks, locs] = findpeaks(abs(corr), 'MinPeakHeight', 29);
    
    decodedBits = double(decodedBits+1)/2;
    
    % remove sync word for descrambling
    payloads = {};
    isPlaceholder = logical([]);
    for i = 1:numel(locs)-1
        startIdx = lags(locs(i))+length(syncAsmBits)+1;
        expectedStopIdx = startIdx+8160-1;

        % case: frames has 8192 or more Bytes
        if lags(locs(i+1)) >= expectedStopIdx
            stopIdx = expectedStopIdx;

        % case: frames has less than 8192 Byte (bitstuffing with zeros)
        elseif lags(locs(i+1)) < expectedStopIdx
            stopIdx = lags(locs(i+1))-1;

        % last frame
        elseif expectedStopIdx > numel(decodedBits)
            break
        end

        payload = zeros(8160, 1);
        payload(1:stopIdx-startIdx+1) = decodedBits(startIdx:stopIdx);
        payloads{end+1} = payload;
        isPlaceholder(end+1) = false;

        % insert zero-filled placeholders for missing frames
        nMissing = round((lags(locs(i+1)) - lags(locs(i))) / 8192) - 1;
        for m = 1:nMissing
            payloads{end+1} = zeros(8160, 1);
            isPlaceholder(end+1) = true;
        end
    end

    % descrambler
    numFrames = numel(payloads);
    frameLenBytes = 1024;
    cvcdus = zeros(numFrames, frameLenBytes-4, 'uint8');

    for i = 1:numFrames
        if isPlaceholder(i)
            continue  % leave row as zeros; do not XOR with PN sequence
        end
        payload = payloads{i};
        payload = reshape(payload, 8, []).';
        payload = uint8(bi2de(payload, 'left-msb'));
        idx = mod(0:numel(payload)-1, 255) + 1;
        payloadDescrambled = diag(bitxor(payload, Descrambler.pn(idx)));
        cvcdus(i,:) = payloadDescrambled;
    end
    
    % plotting
    if Params.plotting
        figure;
        plot(lags, abs(corr)); hold on;
        plot(lags(locs), pks, 'rx'); hold off;
        xlim([0 length(corr)/2]);
        xlabel('Samples');
        ylabel('Cross-correlation');
        title('Cross-correlation of 1ACFFC1D and decoded Softbits');
        grid on;
        if Params.export
            exportgraphics(gcf, "data/plots/corr_decoded.pdf")
        end
    end
end