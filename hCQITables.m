function mcs = hCQITables(tableName,cqi)
% hCQITables CQI tables
%   [RI,PMISET] = hCQITables(TABLE) returns the CQI table indicated by the
%   table name TABLE. TABLE can be one of 'table1', 'table2', 'table3',
%   corresponding to TS 38.214 Tables 5.2.2.1-2 to 5.2.2.1-4, respectively.
%
%   [RI,PMISET] = hCQITables(TABLE,CQI) returns the CQI table row
%   corresponding to the input CQI value.

%   Copyright 2022 The MathWorks, Inc.

switch lower(tableName)
    case 'table1' 
        t = table1();
    case 'table2'
        t = table2();
    case 'table3'
        t = table3();
end

if nargin == 2
    mcs = t(cqi+1,:);
else
    mcs = t;
end

end

% TS 38.214 Table 5.2.2.1-2 4-bit CQI Table 1
function t = table1()

t = [   0   NaN NaN  NaN
        1	2	78	0.1523
        2	2	120	0.2344
        3	2	193	0.3770
        4	2	308	0.6016
        5	2	449	0.8770
        6	2	602	1.1758
        7	4	378	1.4766
        8	4	490	1.9141
        9	4	616	2.4063
        10	6	466	2.7305
        11	6	567	3.3223
        12	6	666	3.9023
        13	6	772	4.5234
        14	6	873	5.1152
        15	6	948	5.5547];
end

% TS 38.214 Table 5.2.2.1-3 4-bit CQI Table 2
function t = table2()

t = [   0   NaN NaN     NaN
        1	2 	78 	    0.1523 
        2	2 	193 	0.3770
        3	2 	449 	0.8770
        4	4 	378 	1.4766
        5	4 	490 	1.9141
        6	4 	616 	2.4063
        7	6 	466 	2.7305
        8	6 	567 	3.3223
        9	6 	666 	3.9023
        10	6 	772 	4.5234
        11	6 	873 	5.1152
        12	8 	711 	5.5547
        13	8 	797 	6.2266
        14	8 	885 	6.9141
        15	8 	948 	7.4063 ];

end

% TS 38.214 Table 5.2.2.1-4 4-bit CQI Table 3
function t = table3()

t = [   0   NaN NaN  NaN
    1	2	30	0.0586
    2	2	50	0.0977
    3	2	78	0.1523
    4	2	120	0.2344
    5	2	193	0.3770
    6	2	308	0.6016
    7	2	449	0.8770
    8	2	602	1.1758
    9	4	378	1.4766
    10	4	490	1.9141
    11	4	616	2.4063
    12	6	466	2.7305
    13	6	567	3.3223
    14	6	666	3.9023
    15	6	772	4.5234];

end
