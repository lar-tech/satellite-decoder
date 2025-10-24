function [DCMap, ACMap] = huffman(Huffmann)
    function dict = generateDict(lengths, symbols)
        code = 0;            
        k = 1;                
        dict = cell(sum(lengths), 2);
        row = 1;

        for len = 1:16
            code = bitshift(code, 1);
            for n = 1:lengths(len)
                bits = dec2bin(code, len) - '0';
                dict{row, 1} = symbols(k);
                dict{row, 2} = sprintf('%d',bits);
                code = code + 1;
                k = k + 1;
                row = row + 1;
            end
        end
    end

    dcDict = generateDict(Huffmann.lDc.lengths, Huffmann.lDc.symbols);
    acDict = generateDict(Huffmann.lAc.lengths, Huffmann.lAc.symbols);
    DCMap.lengths = containers.Map(dcDict(:,1), dcDict(:,2));
    DCMap.symbols = containers.Map(dcDict(:,2), dcDict(:,1));
    ACMap.lengths = containers.Map(acDict(:,1), acDict(:,2));
    ACMap.symbols = containers.Map(acDict(:,2), acDict(:,1));
end