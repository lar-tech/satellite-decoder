function mcus = extraction(cvcdus)
    vcdus = cvcdus(:,1:end-128);
    mpdus = vcdus(:,9:end);
    mpdusPayload = mpdus(:,3:end);
    mpdusHeader = mpdus(:,1:2);
    mpdusHeaderBits = int2bit(mpdusHeader.', 8).';
    mpduPointer = mpdusHeaderBits(:,6:end);
    mpduPointerDec = bi2de(mpduPointer, 'left-msb');
    
    
    mcus = {};
    P = mod(mpduPointerDec(1), 2048);
    idx = double(P + 1);
    i = 1;
    row = 1;
    
    while sum(cellfun(@numel, mcus)) < numel(mpdusPayload)
        % Case: Header geht über 2 Zeilen
        if idx+4 > size(mpdusPayload, 2)
            part1 = mpdusPayload(row, idx:end);
            lenBytes = mpdusPayload(row+1, 5-size(part1,2) : 6-size(part1,2));
            lenBits = int2bit(lenBytes.', 8).';
            lenDec = double(bi2de(lenBits, 'left-msb'));
            totalLen = 6 + lenDec + 1;
            idx = totalLen-size(part1,2)+1;
            part2 = mpdusPayload(row+1, 1:idx);
            mcus{i} = [part1, part2];
            row = row+1;
        else
            lenBytes = mpdusPayload(row, idx+4 : idx+5);
            lenBits = int2bit(lenBytes.', 8).';
            lenDec = double(bi2de(lenBits, 'left-msb'));
            totalLen = 6 + lenDec + 1;
    
            remaining = size(mpdusPayload, 2) - idx + 1;
            
            % Standard case
            if remaining > totalLen
                mcus{i} = mpdusPayload(row, idx : idx+totalLen-1);
                idx = idx+totalLen;
            
            % kein FollowUp -> Paket endet perfekt
            elseif remaining == totalLen
                mcus{i} = mpdusPayload(row, idx:end);
                P = mod(mpduPointerDec(row+1), 2048);
                idx = double(P + 1);
                row = row + 1;
            
            else
                % Standard case über 2 Zeilen
                if row < size(mpdusPayload, 1)
                    part1 = mpdusPayload(row, idx:end);
                    part2 = mpdusPayload(row+1, 1 : totalLen - numel(part1));
                    mcus{i} = [part1, part2];
                    P = mod(mpduPointerDec(row+1), 2048);
                    idx = double(P + 1);
                    row = row + 1;
    
                % Letztes MCU (unvollständig)
                else
                    mcus{i} = mpdusPayload(row, idx:end);
                end
            end
        end
        i = i+1;
    end
end