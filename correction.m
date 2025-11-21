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



    % %% reed-solomon
% % de-interleaving
% deinterleavedBlocks = zeros(size(cvcdus, 1), ReedSolomon.interleavingDepth, ReedSolomon.codeWordLength, 'uint8');
% for i = 1:size(cvcdus, 1)
%     cvcdu = cvcdus(i, :);
%     for j = 1:ReedSolomon.interleavingDepth
%         deinterleavedBlocks(i, j, :) = cvcdu(j:ReedSolomon.interleavingDepth:end);
%     end
% end

% reed-solomon
ReedSolomon.interleavingDepth = 4;
ReedSolomon.codeWordLength = 255;                       
ReedSolomon.messageLength = 223;                        
ReedSolomon.primitivePolynomial = [1 1 0 0 0 0 1 1 1];  % x^8+x^7+x^2+x+1
ReedSolomon.E = 16;

N = ReedSolomon.codeWordLength;
K = ReedSolomon.messageLength;
primPoly = bi2de(ReedSolomon.primitivePolynomial, 'left-msb');
genpoly = rsgenpoly(N, K, primPoly);

% reed-solomon decoder
rsDec = comm.RSDecoder( ...
            'CodewordLength', ReedSolomon.codeWordLength, ...
            'MessageLength', ReedSolomon.messageLength, ...
            'GeneratorPolynomialSource', 'Property', ...
            'GeneratorPolynomial', genpoly, ...
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