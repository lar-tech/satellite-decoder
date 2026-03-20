function corrected = reedsolomon(cvcdus, ReedSolomon, Params)
    primPoly = hex2dec(ReedSolomon.primitivePolynomial);
    fcr = ReedSolomon.firstConsecutiveRoot;
    prim = ReedSolomon.generatorRootGap;
    nRoots = ReedSolomon.numberOfRoots;
    N = ReedSolomon.codeWordLength;
    K = ReedSolomon.messageLength;
    I = ReedSolomon.interleavingDepth;

    % build GF(256) tables
    [gfExp, gfLog] = gfBuildTables(primPoly);

    % build generator polynomial roots
    genRoots = zeros(1, nRoots, 'uint8');
    for i = 0:nRoots-1
        genRoots(i+1) = gfExp(mod(prim * (i + fcr), 255) + 1);
    end

    % precompute LUTs for syndrome evaluation
    genRootsExp = zeros(nRoots, N);
    for i = 1:nRoots
        genRootsExp(i,:) = buildExpLut(gfExp, gfLog, genRoots(i), N-1);
    end

    % elementExp{e}(j) = log(e^(j-1)) for all 256 field elements
    elementExp = zeros(256, nRoots);
    for e = 0:255
        elementExp(e+1,:) = buildExpLut(gfExp, gfLog, e, nRoots-1);
    end

    % process frames
    numFrames = size(cvcdus, 1);
    corrected = cvcdus;
    errors = zeros(numFrames, I, 'int16');

    for fr = 1:numFrames
        frame = cvcdus(fr, :);

        % de-interleave
        for j = 1:I
            codeword = uint8(frame(j:I:end));

            % Decode this codeword
            [decoded, nerr] = rsDecodeBlock(codeword, N, K, nRoots, fcr, prim, gfExp, gfLog, genRootsExp, elementExp);

            errors(fr, j) = nerr;

            % re-interleave
            if nerr >= 0
                corrected(fr, j:I:end) = decoded;
            end
        end
    end

    if Params.plotting
        totalCorrected = sum(errors(errors > 0));
        uncorrectable = sum(errors(:) < 0);
        fprintf('RS: %d symbols corrected, %d blocks uncorrectable (%d/%d frames valid)\n', totalCorrected, uncorrectable, sum(all(errors >= 0, 2)), numFrames);
    end
end

% GF(256) Arithmetic
function [gfExp, gfLog] = gfBuildTables(primPoly)
    gfExp = zeros(1, 512, 'uint16');
    gfLog = zeros(1, 256, 'uint16');

    element = 1;
    gfExp(1) = element;
    for i = 1:511
        element = element * 2;
        if element > 255
            element = bitxor(element, primPoly);
        end
        gfExp(i+1) = element;
        if i < 256
            gfLog(element+1) = i;
        end
    end
end

function r = gfAdd(~, ~, a, b)
    r = bitxor(a, b);
end

function r = gfMul(gfExp, gfLog, a, b)
    if a == 0 || b == 0
        r = 0;
        return;
    end
    res = uint16(gfLog(a+1)) + uint16(gfLog(b+1));
    r = gfExp(res+1);
end

function r = gfDiv(gfExp, gfLog, a, b)
    if a == 0
        r = 0;
        return;
    end
    if b == 0
        r = 0;  % shouldn't happen
        return;
    end
    res = 255 + uint16(gfLog(a+1)) - uint16(gfLog(b+1));
    r = gfExp(res+1);
end

function r = gfPow(gfExp, gfLog, elem, p)
    if elem == 0
        r = 0;
        return;
    end
    log_val = double(gfLog(elem+1));
    res_log = log_val * p;
    m = mod(res_log, 255);
    if m < 0
        m = m + 255;
    end
    r = gfExp(m+1);
end

% Polynomial helpers
function lut = buildExpLut(gfExp, gfLog, val, order)
    lut = zeros(1, order+1);
    if val == 0
        return;
    end
    valExp = gfLog(2);

    valExponentiated = gfLog(1+1);
    valLog = gfLog(val+1);

    for i = 1:order+1
        if val == 0
            lut(i) = 0;
        else
            lut(i) = valExponentiated;
            res = uint16(valExponentiated) + uint16(valLog);
            if res > 255
                valExponentiated = res - 255;
            else
                valExponentiated = res;
            end
        end
    end
end

function r = polyEvalLut(gfExp, gfLog, coeff, valExpLut)
    r = 0;
    for i = 1:length(coeff)
        if coeff(i) ~= 0
            log_coeff = gfLog(coeff(i)+1);
            res = uint16(log_coeff) + uint16(valExpLut(i));
            r = bitxor(r, uint16(gfExp(res+1)));
        end
    end
    r = uint8(r);
end

function r = polyEvalLogLut(gfExp, coeffLog, valExpLut)
    if valExpLut(1) == 0
        if coeffLog(1) ~= 0
            r = gfExp(coeffLog(1)+1);
        else
            r = 0;
        end
        return;
    end
    r = uint16(0);
    for i = 1:length(coeffLog)
        if coeffLog(i) ~= 0
            res = uint16(coeffLog(i)) + uint16(valExpLut(i));
            r = bitxor(r, uint16(gfExp(res+1)));
        end
    end
    r = uint8(r);
end

% rs decode one block
function [decoded, nerrors] = rsDecodeBlock(codeword, N, K, nRoots, fcr, prim, gfExp, gfLog, genRootsExp, elementExp)
    decoded = codeword;

    % reverse byte order
    recvPoly = double(fliplr(codeword));

    % find syndromes
    syndromes = zeros(1, nRoots, 'uint16');
    allZero = true;
    for i = 1:nRoots
        s = polyEvalLut(gfExp, gfLog, recvPoly, genRootsExp(i,:));
        syndromes(i) = s;
        if s ~= 0
            allZero = false;
        end
    end

    if allZero
        % No errors
        nerrors = 0;
        return;
    end

    % berlekamp-massey
    [errorLocator, order] = berlekampMassey(gfExp, gfLog, syndromes, nRoots);

    % chien search: find roots of error locator
    errorLocatorActual = double(errorLocator(1:order+1));
    errorRoots = zeros(1, order);
    rootCount = 0;
    for i = 0:255
        val = polyEvalLut(gfExp, gfLog, errorLocatorActual, elementExp(i+1, 1:order+1));
        if val == 0
            rootCount = rootCount + 1;
            errorRoots(rootCount) = i;
        end
    end

    if rootCount ~= order
        nerrors = -1;
        return;
    end

    % find error locations from roots
    errorLocations = zeros(1, order);
    for i = 1:order
        if errorRoots(i) == 0
            continue;
        end
        loc = gfDiv(gfExp, gfLog, 1, errorRoots(i));
        for j = 0:255
            if gfPow(gfExp, gfLog, j, prim) == loc
                errorLocations(i) = gfLog(j+1);
                break;
            end
        end
    end

    % find error evaluator
    errorEvaluator = polyMulTruncated(gfExp, gfLog, errorLocator(1:order+1), double(syndromes), nRoots-1);

    % find formal derivative of error locator
    errorLocatorDer = zeros(1, order);
    for i = 1:order
        if mod(i, 2) == 1
            errorLocatorDer(i) = errorLocator(i+1);
        else
            errorLocatorDer(i) = 0;
        end
    end

    % forney algorithm: find error values
    errorVals = zeros(1, order);
    for i = 1:order
        if errorRoots(i) == 0
            continue;
        end
        XjInv = errorRoots(i);

        omegaVal = polyEvalLut(gfExp, gfLog, errorEvaluator, elementExp(XjInv+1, 1:nRoots));
        lambdaDerVal = polyEvalLut(gfExp, gfLog, errorLocatorDer, elementExp(XjInv+1, 1:nRoots));

        pow_part = gfPow(gfExp, gfLog, errorRoots(i), fcr - 1);

        errorVals(i) = gfMul(gfExp, gfLog, pow_part, gfDiv(gfExp, gfLog, omegaVal, lambdaDerVal));
    end

    % apply corrections
    for i = 1:order
        loc = errorLocations(i) + 1;
        if loc < 1 || loc > N
            nerrors = -1;
            return;
        end
        recvPoly(loc) = bitxor(uint16(recvPoly(loc)), uint16(errorVals(i)));
    end

    % convert back to original byte order
    decoded = uint8(fliplr(recvPoly));
    nerrors = int16(order);
end

% berlekamp-massey
function [locator, order] = berlekampMassey(gfExp, gfLog, syndromes, nRoots)
    locator = zeros(1, nRoots+1);
    lastLocator = zeros(1, nRoots+1);
    locator(1) = 1;
    lastLocator(1) = 1;

    numerrors = 0;
    lastDiscrepancy = 1;
    delayLength = 1;

    for i = 0:nRoots-1
        discrepancy = syndromes(i+1);
        for j = 1:numerrors
            discrepancy = bitxor(discrepancy, uint16(gfMul(gfExp, gfLog, locator(j+1), syndromes(i-j+1))));
        end

        if discrepancy == 0
            delayLength = delayLength + 1;
            continue;
        end

        if 2 * numerrors <= i
            newLast = zeros(1, nRoots+1);

            for j = 0:nRoots
                if j <= find(lastLocator ~= 0, 1, 'last')-1
                    newLast(j + delayLength + 1) = gfDiv(gfExp, gfLog, gfMul(gfExp, gfLog, lastLocator(j+1), discrepancy), lastDiscrepancy);
                end
            end

            lastOrder = find(lastLocator ~= 0, 1, 'last') - 1;
            if isempty(lastOrder); lastOrder = 0; end

            temp_locator = locator;
            max_idx = lastOrder + delayLength + 1;
            for j = 1:max_idx
                locator(j) = bitxor(uint16(locator(j)), uint16(newLast(j)));
            end

            lastLocator = temp_locator;

            tempOrder = find(locator ~= 0, 1, 'last') - 1;
            if isempty(tempOrder); tempOrder = 0; end
            lastOrderSave = find(lastLocator ~= 0, 1, 'last') - 1;
            if isempty(lastOrderSave); lastOrderSave = 0; end

            numerrors = i + 1 - numerrors;
            lastDiscrepancy = discrepancy;
            delayLength = 1;
        else
            lastOrder = find(lastLocator ~= 0, 1, 'last') - 1;
            if isempty(lastOrder); lastOrder = 0; end

            for j = 0:lastOrder
                shiftedIdx = j + delayLength + 1;
                correction = gfDiv(gfExp, gfLog, ...
                    gfMul(gfExp, gfLog, lastLocator(j+1), discrepancy), lastDiscrepancy);
                locator(shiftedIdx) = bitxor(uint16(locator(shiftedIdx)), uint16(correction));
            end

            delayLength = delayLength + 1;
        end
    end

    order = numerrors;
    locator = locator(1:order+1);
end

% polynomial multiply
function res = polyMulTruncated(gfExp, gfLog, a, b, maxOrder)
    res = zeros(1, maxOrder+1);
    for i = 1:length(a)
        if a(i) == 0
            continue;
        end
        for j = 1:length(b)
            if b(j) == 0
                continue;
            end
            idx = i + j - 1;
            if idx <= maxOrder + 1
                res(idx) = bitxor(uint16(res(idx)), uint16(gfMul(gfExp, gfLog, a(i), b(j))));
            end
        end
    end
end