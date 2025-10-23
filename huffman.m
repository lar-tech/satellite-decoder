function [dcDict, acDict] = huffman(Huffmann)
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
                dict{row, 2} = bits;
                code = code + 1;
                k = k + 1;
                row = row + 1;
            end
        end
    end

    dcDict = generateDict(Huffmann.lDc.lengths, Huffmann.lDc.symbols);
    acDict = generateDict(Huffmann.lAc.lengths, Huffmann.lAc.symbols);
end