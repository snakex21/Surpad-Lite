function [code, finalState] = HelperGPSL2CRangingCode(PRNID, type)
%HelperGPSL2CRangingCode CM/CL-code generation for GPS satellites
%
%   Note: This is a helper and its API and/or functionality may change
%   in subsequent releases.
%
%   [CODE,FINALSTATE] = HelperGPSL2CRangingCode(PRNID,TYPE) generates civil
%   moderate or civil long code for the specified PRNID. TYPE is a string
%   scalar or a character vector with possible values of "CM" | "CL". PRNID
%   is a scalar or a vector integer value(s) with valid vales from 1 to 63
%   and 159 to 210. Code is a vector or a matrix with number of rows equal
%   to the code period and number of columns equal to number of elements in
%   PRNID. When TYPE is "CM", code period is 10230 and when TYPE is "CL",
%   code period is 767250. FINALSTATE is the final state of the modular
%   linear feedback shift register after generating the code. This is
%   useful to validate against the final state mentioned in Tables 3-IIa,
%   3-IIb and 6-II in IS-GPS-200L [1].
%
%   References:
%    [1] IS-GPS-200L. "NAVSTAR GPS Space Segment/Navigation User Segment
%        Interfaces." GPS Enterprise Space & Missile Systems Center (SMC) -
%        LAAFB, May 14, 2020.
%
%   See also HelperGPSNavigationConfig, HelperGPSCEIConfig,
%   HelperGPSNAVDataEncode.

%   Copyright 2021 The MathWorks, Inc.

numPRN = numel(PRNID);
initState = getInitialState(PRNID(:), type);
% In a modular LFSR, generator polynomial is also referred as toggle mask
% and is set to following binary vector as specified in Figure 3-13 of
% IS-GPS-200K.
toggleMask = [1;0;0;1;0;0;1;0;1;0;0;1;0;0;1;0;1;0;1;0;0;1;1;1;1;0;0];
if strcmpi(type,"CM")
    % ShortCyclePeriod is the number of output bits generated before
    % the registers are reset to an initial state. For CM code, short cycle
    % period is 10230 as mentioned in Section 3.2.1.4 of IS-GPS-200K.
    shortCyclePeriod = 10230;
else % CL code
    % ShortCyclePeriod is the number of output bits generated before the
    % registers are reset to an initial state. For CL code, short cycle
    % period is 767250 as mentioned in Section 3.2.1.5 of IS-GPS-200K.
    shortCyclePeriod = 767250;
end

code = zeros(shortCyclePeriod,numPRN,'int8');
finalState = zeros(size(initState.'),'int8');
for iPRN = 1:numPRN
    [code(:,iPRN), finalState(:,iPRN)] = ModularLFSR(initState(iPRN,:), toggleMask, shortCyclePeriod);
end
end

function [sequence,finalState] = ModularLFSR(initialState, toggleMask, numOutputBits)
%ModularLFSR Implements a modular type shift register with specified
% initial state and generator polynomial.
%   SEQUENCE = ModularLFSR(INITIALSTATE, TOGGLEMASK, NUMOUTPUTBITS)
%   generates the output sequence, SEQUENCE of modular type shift register
%   with initial state, INITIALSTATE and generator polynomial, TOGGLEMASK.
%   NUMOUTPUTBITS is the required number of output bits specified as a
%   scalar. INITIALSTATE is a binary column vector of the initial state of
%   modular LFSR. TOGGLEMASK is a binary column vector of the generator
%   polynomial of modular LFSR.

sequence = zeros(numOutputBits, 1, 'int8');
lfsrReg = initialState(:);
% Number of registers in modular LFSR
numReg = length(initialState);
for i = 1:numOutputBits - 1
    lsb = lfsrReg(numReg);
    % Shift the register bits
    lfsrReg(2:end) = lfsrReg(1:numReg - 1);
    lfsrReg(1) = 0;
    % When output bit is 1, the bits in the taps position toggle
    if lsb
        lfsrReg = xor(lfsrReg,toggleMask);
    end
    sequence(i) = lsb;
end
sequence(numOutputBits) = lfsrReg(numReg);
finalState = lfsrReg(:);
end

function s = getInitialState(PRNID,type)
if strcmpi(type,"CM")
    allStates = [742417664;756014035;002747144;066265724;601403471;703232733;124510070;617316361; ...
        047541621;733031046;713512145;024437606;021264003;230655351;001314400;222021506; ...
        540264026;205521705;064022144;120161274;044023533;724744327;045743577;741201660; ...
        700274134;010247261;713433445;737324162;311627434;710452007;722462133;050172213; ...
        500653703;755077436;136717361;756675453;435506112;771353753;226107701;022025110; ...
        402466344;752566114;702011164;041216771;047457275;266333164;713167356;060546335; ...
        355173035;617201036;157465571;767360553;023127030;431343777;747317317;045706125; ...
        002744276;060036467;217744147;603340174;326616775;063240065;111460621; ...
        ones(95,1); ...
        604055104;157065232;013305707;603552017;230461355;603653437;652346475;743107103; ...
        401521277;167335110;014013575;362051132;617753265;216363634;755561123;365304033; ...
        625025543;054420334;415473671;662364360;373446602;417564100;000526452;226631300; ...
        113752074;706134401;041352546;664630154;276524255;714720530;714051771;044526647; ...
        207164322;262120161;204244652;202133131;714351204;657127260;130567507;670517677; ...
        607275514;045413633;212645405;613700455;706202440;705056276;020373522;746013617; ...
        132720621;434015513;566721727;140633660];
else % CL code
    allStates = [624145772;506610362;220360016;710406104;001143345;053023326; ...
        652521276;206124777;015563374;561522076;023163525;117776450;606516355; ...
        003037343;046515565;671511621;605402220;002576207;525163451;266527765; ...
        006760703;501474556;743747443;615534726;763621420;720727474;700521043; ...
        222567263;132765304;746332245;102300466;255231716;437661701;717047302; ...
        222614207;561123307;240713073;101232630;132525726;315216367;377046065; ...
        655351360;435776513;744242321;024346717;562646415;731455342;723352536; ...
        000013134;011566642;475432222;463506741;617127534;026050332;733774235; ...
        751477772;417631550;052247456;560404163;417751005;004302173;715005045;001154457; ...
        ones(95,1); ...
        605253024;063314262;066073422;737276117;737243704;067557532;227354537; ...
        704765502;044746712;720535263;733541364;270060042;737176640;133776704; ...
        005645427;704321074;137740372;056375464;704374004;216320123;011322115; ...
        761050112;725304036;721320336;443462103;510466244;745522652;373417061; ...
        225526762;047614504;034730440;453073141;533654510;377016461;235525312; ...
        507056307;221720061;520470122;603764120;145604016;051237167;033326347; ...
        534627074;645230164;000171400;022715417;135471311;137422057;714426456; ...
        640724672;501254540;513322453];
end
numReg = 27; % 27 registers
temp = allStates(PRNID);
s = zeros(length(PRNID), numReg);
for iPRN = 1:length(PRNID)
    tempBits = oct2poly(temp(iPRN));
    if length(tempBits) ~= numReg
        allBits = [zeros(1,numReg-length(tempBits)),tempBits];
    else
        allBits = tempBits;
    end
    s(iPRN,:) = allBits;
end
end