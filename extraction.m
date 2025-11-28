function [mcus, qualityFactors, apids] = extraction(cvcdus, Params)
    function [row, idx, validHeader] = checkHeader(Header, apid, row, idx, nCols)
        if ~(Header(1) == 8 && ismember(apid, [64 65 68 70]) && Header(7) == 0)
            % go to next idx
            if idx < nCols
                idx = idx + 1;
            else
                row = row + 1;
                idx = 1;
            end
            validHeader = 0;
        else
            validHeader = 1;
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
    mpdusHeaderBits = int2bit(mpdusHeader.', 8).';
    mpduPointer = mpdusHeaderBits(:,6:end);
    mpduPointerDec = bi2de(mpduPointer, 'left-msb');
    
    [nRows, nCols] = size(mpdusPayload);
    totalBytes = numel(mpdusPayload);
    
    maxPackets = nRows * 5;
    pp = cell(1, maxPackets);
    counter = int16(zeros(1,maxPackets));
    
    row = 1;
    idx = double(mod(mpduPointerDec(1), 2048) + 1);
    i = 1;
    j = 1;
    processed = 0;
    validHeader = 0;
    
    while processed < totalBytes && row <= nRows
    
        tempPP = [];
    
        % Check: header continues onto the next row
        if idx+7 > nCols
            % header spans across row and row + 1
            part1    = mpdusPayload(row, idx:end);
            tmpPart2 = mpdusPayload(row+1, 1:17); % worst case is 17 bytes in next row
            tmpHeader = [part1, tmpPart2];
    
            apid = tmpHeader(2);
            
            [row, idx, validHeader] = checkHeader(tmpHeader, apid, row, idx, nCols);
            if ~validHeader
                continue
            end
            counter(j) = calcCounter(tmpHeader);
    
            lenBytes = tmpHeader(5:6);
            lenDec = double(uint16(lenBytes(1)) * 256 + uint16(lenBytes(2))); % eleganteres int2bit
            totalLen = 6 + lenDec + 1;
            idx = totalLen - numel(part1) + 1;
            part2  = mpdusPayload(row+1, 1:idx);
            tempPP = [part1, part2];
            row = row + 1;
            processed = processed + totalLen;
    
        else
            % header fully contained in current row
            apid = mpdusPayload(row, idx+1);
            [row, idx, validHeader] = checkHeader(mpdusPayload(row, idx:idx+7), apid, row, idx, nCols);
            if ~validHeader
                continue
            end
    
            counter(j) = calcCounter(mpdusPayload(row, idx:idx+4));
    
            lenBytes = mpdusPayload(row, idx+4:idx+5);
            lenDec = double(uint16(lenBytes(1)) * 256 + uint16(lenBytes(2)));
            totalLen = 6 + lenDec + 1;
    
            remaining = nCols - idx + 1;
    
            if remaining > totalLen
                % standard case
                tempPP = mpdusPayload(row, idx:idx+totalLen-1);
                idx = idx + totalLen;
    
            elseif remaining == totalLen
                % no follow-up packet -> packet ends perfectly
                tempPP = mpdusPayload(row, idx:end);
                if row < nRows
                    idx = double(mod(mpduPointerDec(row+1), 2048) + 1);
                end
                row = row + 1;
    
            elseif row < nRows
                % overflow into next row
                part1 = mpdusPayload(row, idx:end);
                part2 = mpdusPayload(row+1, 1:totalLen-numel(part1));
                tempPP = [part1, part2];
                P = mod(mpduPointerDec(row+1), 2048);
                idx = double(P + 1);
                row = row + 1;
    
            else
                % last incomplete mcu
                tempPP = mpdusPayload(row, idx:end);
                row = nRows + 1;
            end
    
            processed = processed + totalLen;
        end

        % handle missing partial packets
        if i > 1
            % normal case
            if counter(j) - counter(j-1) == 1 || counter(j) == 0
                pp{i} = tempPP; 
                j = j + 1;

            % missing partial packets
            elseif counter(j) - counter(j-1) > 1
                i = i + counter(j) - counter(j-1);
                pp{i} = tempPP;
                j = j + 1;
            else
                continue
            end
        else
            % normal case for first packet
            pp{i} = tempPP;
            j = j + 1;
        end
        i = i + 1;
    end
    
    % cut to actual length
    pp = pp(1:i-1);   
    
    % extract mcus
    nPP = numel(pp);
    mcus = cell(1, nPP);
    qualityFactors = zeros(1, nPP);
    apids = zeros(1, nPP);
    
    for k = 1:nPP
        if ~isempty(pp{k})
            apids(k) = pp{k}(2);
            qualityFactors(k) = pp{k}(20);
            mcusDec = pp{k}(21:end);
            mcus{k} = int2bit(mcusDec.', 8).';
        end
    end

    if Params.plotting
        fprintf("Extracted %d MCUs. %d MCUs are missing.\n", nPP, sum(cellfun(@isempty, pp)));
    end
end