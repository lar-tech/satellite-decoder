function vcdus = correction(cvcdus, ReedSolomon, Params)
    % de-interleaving
    deinterleavedBlocks = zeros(size(cvcdus, 1), ReedSolomon.interleavingDepth, ReedSolomon.codeWordLength, 'uint8');
    for i = 1:size(cvcdus, 1)
        cvcdu = cvcdus(i, :);
        for j = 1:ReedSolomon.interleavingDepth
            deinterleavedBlocks(i, j, :) = cvcdu(j:ReedSolomon.interleavingDepth:end);
        end
    end
    
    % reed-solomon decoder
    generatorPolynomial = rsgenpoly( ...
                            ReedSolomon.codeWordLength, ...
                            ReedSolomon.messageLength, ...
                            bi2de(ReedSolomon.primitivePolynomial, ...
                            'left-msb'));
    rsDec = comm.RSDecoder( ...
                'CodewordLength', ReedSolomon.codeWordLength, ...
                'MessageLength', ReedSolomon.messageLength, ...   
                'GeneratorPolynomialSource', 'Property', ...
                'GeneratorPolynomial', generatorPolynomial, ...
                'PrimitivePolynomialSource', 'Property', ...
                'PrimitivePolynomial', ReedSolomon.primitivePolynomial ...
            );
    correctedBlocks = zeros(size(deinterleavedBlocks, 1), ReedSolomon.interleavingDepth, ReedSolomon.messageLength, 'uint8');
    numErrors       = zeros(size(deinterleavedBlocks, 1), ReedSolomon.interleavingDepth);
    for i = 1:size(deinterleavedBlocks, 1)
        for j = 1:ReedSolomon.interleavingDepth
            [decoded, errCount] = rsDec(squeeze(deinterleavedBlocks(i, j, :)));
            correctedBlocks(i, j, :) = decoded;
            numErrors(i, j) = errCount;
            fprintf('Frame %d, Block %d: %d Bytefehler korrigiert\n', i, j, errCount);
        end
    end
    
    % re-interleaving
    reinterleavedBytes = zeros(size(correctedBlocks, 1), ReedSolomon.interleavingDepth * ReedSolomon.messageLength, 'uint8');
    for i = 1:size(correctedBlocks, 1)
        correctedBlock = squeeze(correctedBlocks(i, :, :));
        reinterleavedBytes(i, :) = reshape(correctedBlock.', 1, []);
    end
    bitsPerByte = 8;
    reinterleavedBits = de2bi(reinterleavedBytes, bitsPerByte, 'left-msb');
    reinterleavedBits = reshape(reinterleavedBits.', size(correctedBlocks, 1), []);
    vcdus = logical(reinterleavedBits);
end