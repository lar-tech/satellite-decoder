function cadus = decode(frames, Viterbi, Descrambler)

    % viterbi-decoder
    trellis = poly2trellis(Viterbi.constLen, Viterbi.codeGenPoly);
    vDec = comm.ViterbiDecoder( ...
            'TrellisStructure', trellis, ...
            'InputFormat', 'Hard',...
            'TracebackDepth', Viterbi.tblen,...
            'TerminationMethod','Continuous'...
            );
    decodedBits = cell(size(frames));
    for k = 1:numel(frames)
        frame = frames{k}*10;
        decodedBits{k} = vDec(frame(:));
        reset(vDec);
    end
    
    % descrambler
    descrambler = comm.Descrambler( ...
                            'CalculationBase', Descrambler.base, ...
                            'Polynomial', Descrambler.polynom, ...
                            'InitialConditions', Descrambler.init ...
                            );
    cadus = cell(size(decodedBits));
    for k = 1:numel(decodedBits)
        decodedBit = logical(decodedBits{k});
        cadus{k} = descrambler(decodedBit(:));
        reset(descrambler);
    end
   
end