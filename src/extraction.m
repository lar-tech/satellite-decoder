function [mcus, qualityFactors, apids, Meta] = extraction(cvcdus, Params)
    function remaining = readPackets(bytes, multiplePackets)
        remaining = uint8([]);
        pos = 1;
        while pos <= numel(bytes)
            % keep an incomplete header for the next frame
            if numel(bytes)-pos+1 < 6
                remaining = bytes(pos:end);
                return
            end
            lenBytes = bytes(pos+4:pos+5);
            lenDec = double(lenBytes(1))*256 + double(lenBytes(2));
            totalLen = 6 + lenDec + 1;
            if bitshift(bytes(pos),-5) ~= 0
                return  % resume at the next first header pointer
            end
            if pos+totalLen-1 > numel(bytes)
                remaining = bytes(pos:end);
                return
            end

            tempPP = bytes(pos:pos+totalLen-1);
            if totalLen >= 21 && tempPP(1) == 8 && ismember(tempPP(2), [64 65 68]) && ...
                    tempPP(18) == 255 && tempPP(19) == 240 && ...
                    tempPP(15) <= 182 && mod(double(tempPP(15)),14) == 0 && ...
                    tempPP(20) >= 1 && tempPP(20) <= 100
                pp{end+1} = tempPP;
            end
            pos = pos + totalLen;
            if ~multiplePackets
                return
            end
        end
    end

    function counter = calcCounter(Header)
        counterPP1 = Header(3).';
        counterPP1 = int2bit(counterPP1.', 8).';
        counterPP2 = Header(4).';
        counterPP2 = int2bit(counterPP2.', 8).';
        counterBit = [counterPP1 counterPP2];
        counterBit = counterBit(:,3:end);
        counter = int16(bi2de(counterBit, 'left-msb'));
    end
    
    % extract header infos
    vcdus = cvcdus(:,1:end-128);
    mpdus = vcdus(:,9:end);
    mpdusPayload = mpdus(:,3:end);
    mpdusHeader = mpdus(:,1:2);
    mpduPointerDec = double(bitand(uint16(mpdusHeader(:,1))*256 + ...
                                 uint16(mpdusHeader(:,2)), uint16(2047)));
    [nRows, nCols] = size(mpdusPayload);

    pp = {};
    partialPP = uint8([]);
    lastCounter = [];
    lastId = [];

    for row = 1:nRows
        frame = cvcdus(row,:);
        if ~any(frame) || bitshift(frame(1),-6) ~= 1
            partialPP = uint8([]);
            lastCounter = [];
            continue
        end

        % do not join packet fragments across missing frames or different channels
        counter = double(frame(3))*65536 + double(frame(4))*256 + double(frame(5));
        vcduId = double(frame(1))*256 + double(frame(2));
        if ~isempty(lastCounter) && (mod(counter-lastCounter,2^24) ~= 1 || vcduId ~= lastId)
            partialPP = uint8([]);
        end
        lastCounter = counter;
        lastId = vcduId;

        idx = mpduPointerDec(row) + 1;
        if idx == 2048
            % no new packet header in this frame
            if ~isempty(partialPP)
                partialPP = readPackets([partialPP, mpdusPayload(row,:)], false);
            end
        elseif idx <= nCols
            if ~isempty(partialPP)
                readPackets([partialPP, mpdusPayload(row,1:idx-1)], false);
            end
            % the pointer starts a new packet, even if the old packet was incomplete
            partialPP = readPackets(mpdusPayload(row,idx:end), true);
        else
            partialPP = uint8([]);
        end
    end

    % clean up the partial packets
    nPP = numel(pp);
    validApid = [64 65 68 70];
    % preallocate with 0 and set it to 1 if the thumbnail is correct
    keepPP = false(1, nPP);
    
    expectedCounter   = 0:14:182;
    nPerThumb  = numel(expectedCounter);
    
    % only non-empty pp
    nonEmptyIdx = find(~cellfun(@isempty, pp));   
    
    % extract apid of all the pp
    apidAll = cellfun(@(p) p(2), pp(nonEmptyIdx));  
    
    for a = 1:numel(validApid)
        apidVal = validApid(a);  
        % index of the non-empty pp of the current apidVal
        idxApid = nonEmptyIdx(apidAll == apidVal);        
    
        mcuCounters = cellfun(@(p) double(p(15)), pp(idxApid));
        % gives the start of each thumbnail
        startThumbnail = find(mcuCounters == 0);
    
        for k = 1:numel(startThumbnail)
    
            startIdx = startThumbnail(k);
            endIdx = startIdx;
        
            % continue the segment only while the next counter exists and increases strictly (transition 182 -> 0)  
            while endIdx + 1 <= numel(mcuCounters) && mcuCounters(endIdx + 1) > mcuCounters(endIdx)
                endIdx = endIdx + 1;
            end
            thumbnailCounters = mcuCounters(startIdx:endIdx);
        
            % keep the segment only if length and counter pattern match exactly
            packetCounters = cellfun(@calcCounter, pp(idxApid(startIdx:endIdx)));
            if numel(thumbnailCounters) == nPerThumb && isequal(thumbnailCounters(:).', expectedCounter) && ...
                    all(mod(diff(double(packetCounters)),16384) == 1)
                keepPP(idxApid(startIdx:endIdx)) = true;
            end
        end
    end
    
    % keep partial scan lines when packets are placed by timestamp and MCU number
    if isfield(Params, 'keepPartialScans') && Params.keepPartialScans
        keepPP(:) = true;
    end

    ppClean = pp(keepPP);
    nPP = numel(ppClean);
    mcus = cell(1, nPP);
    qualityFactors = zeros(1, nPP);
    apids = zeros(1, nPP);
    Meta.mcu = zeros(1, nPP);
    Meta.time = zeros(1, nPP);
    Meta.sequence = zeros(1, nPP);
    
    for i = 1:nPP
        p = ppClean{i};
        apids(i) = p(2);
        qualityFactors(i) = p(20);
        mcusDec = p(21:end);
        mcus{i} = int2bit(mcusDec.', 8).';
        Meta.mcu(i) = p(15);
        Meta.sequence(i) = double(calcCounter(p));
        Meta.time(i) = (double(p(7))*256+double(p(8)))*86400000 + ...
                      double(p(9))*2^24+double(p(10))*65536+double(p(11))*256+double(p(12));
    end
    
    Meta.apid = apids;

    if Params.plotting
        fprintf("Extracted %d MCUs.\n", nPP);
    end
end
