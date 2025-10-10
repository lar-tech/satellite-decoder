function vcdus = correction(cvcdus, ReedSolomon, Params)
    % bit -> byte
    for i = 1:numel(cvcdus)
        cvcdu = reshape(cvcdus{i}, 8, []).';
        cvcdus{i} = bi2de(cvcdu, 'left-msb');
    end
    
    % de-interleaving
    deinterleavedBlocks = cell(1, numel(cvcdus));
    for i = 1:numel(cvcdus)
        cvcdu = cvcdus{i};
        rsBlock = zeros(ReedSolomon.interleavingDepth, ReedSolomon.codeWordLength, 'uint8');
        for j = 1:ReedSolomon.interleavingDepth
            rsBlock(j, :) = cvcdu(j:ReedSolomon.interleavingDepth:end);
        end
        deinterleavedBlocks{i} = rsBlock;
    end
    
    % reed-solomon decoder
    generatorPolynomial = rsgenpoly(ReedSolomon.codeWordLength, ReedSolomon.messageLength, bi2de(ReedSolomon.primitivePolynomial, 'left-msb'));
    rsDec = comm.RSDecoder( ...
                'CodewordLength', ReedSolomon.codeWordLength, ...    
                'MessageLength', ReedSolomon.messageLength, ...     
                'GeneratorPolynomialSource', 'Property', ...
                'GeneratorPolynomial', generatorPolynomial, ...
                'PrimitivePolynomialSource', 'Property', ...
                'PrimitivePolynomial', ReedSolomon.primitivePolynomial ...
                );
    correctedBlocks = cell(1, numel(deinterleavedBlocks));
    numErrors = cell(1, numel(deinterleavedBlocks));
    for i = 1:numel(deinterleavedBlocks)
        rsBlock = deinterleavedBlocks{i};
        correctedBlock = zeros(4, ReedSolomon.messageLength, 'uint8');
        numError = zeros(4,1);
        for j = 1:4
            [correctedBlock(j,:), numError(j)] = rsDec(rsBlock(j,:).');
            if Params.plotting
                fprintf('CVCDU %d, Block %d: %d byte errors corrected.\n', i, j, numError(j));
            end
        end
        correctedBlocks{i} = correctedBlock;
        numErrors{i} = numError;
    end
    
    % re-interleaving
    vcdus = cell(1, numel(correctedBlocks));
    for i = 1:numel(correctedBlocks)
        correctedBlock = correctedBlocks{i};
        reinterleavedBlock = zeros(1, ReedSolomon.interleavingDepth*ReedSolomon.messageLength, 'uint8');
        idx = 1;
        for col = 1:ReedSolomon.messageLength
            for row = 1:ReedSolomon.interleavingDepth
                reinterleavedBlock(idx) = correctedBlock(row, col);
                idx = idx + 1;
            end
        end
        bits = de2bi(reinterleavedBlock, 8, 'left-msb');
        bits = reshape(bits.', 1, []);
        vcdus{i} = logical(bits(:));
    end
end